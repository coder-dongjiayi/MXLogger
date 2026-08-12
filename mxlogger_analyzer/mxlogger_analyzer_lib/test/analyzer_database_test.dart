import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

LogRecord record({
  String name = "app",
  String tag = "tag",
  String msg = "message",
  int level = 0,
  required int timestamp,
}) {
  return LogRecord(
    name: name,
    tag: tag,
    msg: msg,
    level: level,
    threadId: 1,
    isMainThread: 1,
    timestamp: timestamp,
  );
}

void main() {
  late Directory tempDir;
  late AnalyzerDatabase database;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("mxlogger_test");
    database = AnalyzerDatabase(tempDir.path);
    database.open();
  });

  tearDown(() {
    database.dispose();
    tempDir.deleteSync(recursive: true);
  });

  test("批量插入 + timestamp 去重", () {
    final InsertSummary first = database.insertRecords([
      record(timestamp: 1000, level: 0),
      record(timestamp: 1001, level: 1),
      record(timestamp: 1002, level: 3),
    ]);
    expect(first.inserted, 3);
    expect(first.duplicated, 0);

    // 重复导入同一批数据全部被忽略
    final InsertSummary second = database.insertRecords([
      record(timestamp: 1000),
      record(timestamp: 1001),
      record(timestamp: 1003),
    ]);
    expect(second.inserted, 1);
    expect(second.duplicated, 2);
    expect(database.count(), 4);
  });

  test("关键词 scope + 等级 + 排序", () {
    database.insertRecords([
      record(timestamp: 1, msg: "user login success", level: 1, name: "Auth"),
      record(timestamp: 2, msg: "network timeout", level: 3, name: "Net"),
      record(timestamp: 3, msg: "user logout", level: 1, tag: "auth session"),
      record(timestamp: 4, msg: "crash: 100% cpu", level: 4, name: "user-service"),
    ]);

    // 默认全范围搜索 + 时间升序（对齐设计稿文件顺序）
    final List<Map<String, Object?>> all =
        database.selectLogs(const LogQuery(keyword: "user"));
    expect(all.length, 3);
    expect(all.first["timestamp"], 1);

    // 仅内容
    final List<Map<String, Object?>> content = database
        .selectLogs(const LogQuery(keyword: "user", scope: MxSearchScope.content));
    expect(content.length, 2);

    // 仅 name
    final List<Map<String, Object?>> byName =
        database.selectLogs(const LogQuery(keyword: "user", scope: MxSearchScope.name));
    expect(byName.length, 1);
    expect(byName.first["name"], "user-service");

    final List<Map<String, Object?>> byLevel =
        database.selectLogs(const LogQuery(levels: [1, 4]));
    expect(byLevel.length, 3);

    // LIKE 通配符按字面匹配，不放大结果
    expect(database.selectLogs(const LogQuery(keyword: "100%")).length, 1);
    expect(database.selectLogs(const LogQuery(keyword: "%")).length, 1);
  });

  test("tag 分词精确过滤 + name 精确过滤 + 时间范围", () {
    database.insertRecords([
      record(timestamp: 10, tag: "network download", name: "NetworkClient"),
      record(timestamp: 20, tag: "network", name: "NetworkClient"),
      record(timestamp: 30, tag: "networking", name: "Other"),
      record(timestamp: 5, tag: "network,upload", name: "Uploader"),
    ]);

    // "network" 只命中分词后的完整 tag（空格或逗号分隔），不命中 "networking"
    final List<Map<String, Object?>> byTag =
        database.selectLogs(const LogQuery(tags: ["network"]));
    expect(byTag.length, 3);

    // 逗号分隔的第二个 tag 也可精确命中
    final List<Map<String, Object?>> byCommaTag =
        database.selectLogs(const LogQuery(tags: ["upload"]));
    expect(byCommaTag.length, 1);
    expect(byCommaTag.first["timestamp"], 5);

    // 多个 tag 取「或」：network 命中 3 条、upload 命中的 ts5 已在其中，去重后仍 3 条
    final List<Map<String, Object?>> byTagsOr =
        database.selectLogs(const LogQuery(tags: ["network", "upload"]));
    expect(byTagsOr.length, 3);

    // networking 不被 network 命中，加入后并集为 4 条
    final List<Map<String, Object?>> byTagsOr2 =
        database.selectLogs(const LogQuery(tags: ["network", "networking"]));
    expect(byTagsOr2.length, 4);

    final List<Map<String, Object?>> byName =
        database.selectLogs(const LogQuery(names: ["NetworkClient"]));
    expect(byName.length, 2);

    // 多个 name 取「或」
    final List<Map<String, Object?>> byNamesOr =
        database.selectLogs(const LogQuery(names: ["NetworkClient", "Uploader"]));
    expect(byNamesOr.length, 3);

    final List<Map<String, Object?>> byTime =
        database.selectLogs(const LogQuery(fromUs: 15, toUs: 30));
    expect(byTime.length, 2);
    expect(byTime.first["timestamp"], 20);
  });

  test("分页 limit/offset + 过滤总数 countLogs", () {
    database.insertRecords([
      for (int i = 0; i < 120; i++)
        record(timestamp: i + 1, level: i % 2, msg: "log $i"),
    ]);

    // 第一页/第二页按时间升序切片，末页不足一页只返回剩余
    final List<Map<String, Object?>> page1 =
        database.selectLogs(const LogQuery(limit: 50, offset: 0));
    expect(page1.length, 50);
    expect(page1.first["timestamp"], 1);
    expect(page1.last["timestamp"], 50);

    final List<Map<String, Object?>> page2 =
        database.selectLogs(const LogQuery(limit: 50, offset: 50));
    expect(page2.first["timestamp"], 51);

    final List<Map<String, Object?>> page3 =
        database.selectLogs(const LogQuery(limit: 50, offset: 100));
    expect(page3.length, 20);

    // countLogs 与过滤条件一致，忽略 limit/offset
    expect(database.countLogs(const LogQuery()), 120);
    expect(database.countLogs(const LogQuery(levels: [0], limit: 50)), 60);

    // 过滤 + 分页组合：等级过滤后再切片
    final List<Map<String, Object?>> filteredPage =
        database.selectLogs(const LogQuery(levels: [0], limit: 50, offset: 50));
    expect(filteredPage.length, 10);
  });

  test("等级统计 / 起止时间 / meta / 清空", () {
    database.insertRecords([
      record(timestamp: 10, level: 0),
      record(timestamp: 11, level: 0),
      record(timestamp: 12, level: 3),
    ], fileHeader: "{\"os\":\"iOS\"}");
    database.setMeta("fileName", "a.mx");

    expect(database.levelCounts()[0], 2);
    expect(database.levelCounts()[3], 1);
    expect(database.timeBounds(), (minUs: 10, maxUs: 12));
    expect(database.getMeta("fileName"), "a.mx");
    expect(database.firstFileHeader(), "{\"os\":\"iOS\"}");

    database.clear();
    expect(database.count(), 0);
    expect(database.levelCounts(), isEmpty);
    expect(database.timeBounds(), isNull);
    expect(database.getMeta("fileName"), isNull);
  });
}
