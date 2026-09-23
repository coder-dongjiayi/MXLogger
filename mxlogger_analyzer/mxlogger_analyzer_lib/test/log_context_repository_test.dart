import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 上下文查询：以 timestamp 为游标取锚点前后的全局日志，离锚点近的在前，
/// 到头时按实际条数返回；位置统计与筛选无关。
void main() {
  late Directory tempDir;
  late AnalyzerDatabase database;
  late HomeRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("mx_context_test");
    database = AnalyzerDatabase(tempDir.path);
    database.open();
    repository = HomeRepository(() async => database);
    // 50 条：timestamp 1000..1049，等级轮转
    database.insertRecords([
      for (int i = 0; i < 50; i++)
        LogRecord(
          name: "app",
          tag: i.isEven ? "net" : "ui",
          msg: "log $i",
          level: i % 5,
          threadId: 1,
          isMainThread: 1,
          timestamp: 1000 + i,
        ),
    ]);
  });

  tearDown(() {
    database.dispose();
    tempDir.deleteSync(recursive: true);
  });

  LogModel anchorAt(int timestamp) => LogModel(level: 0, timestamp: timestamp);

  List<int> timestamps(List<LogModel> logs) =>
      logs.map((LogModel log) => log.timestamp).toList();

  test("锚点居中：前后各 limit 条，离锚点近的在前，位置按全局统计", () async {
    final LogContext context = await repository.fetchContext(anchorAt(1025), limit: 5);
    expect(timestamps(context.older), [1024, 1023, 1022, 1021, 1020]);
    expect(timestamps(context.newer), [1026, 1027, 1028, 1029, 1030]);
    expect(context.olderCount, 25);
    expect(context.total, 50);
  });

  test("锚点在最早 / 最新一端时另一侧为空", () async {
    final LogContext first = await repository.fetchContext(anchorAt(1000), limit: 5);
    expect(first.older, isEmpty);
    expect(first.olderCount, 0);
    expect(timestamps(first.newer), [1001, 1002, 1003, 1004, 1005]);

    final LogContext last = await repository.fetchContext(anchorAt(1049), limit: 5);
    expect(last.newer, isEmpty);
    expect(last.olderCount, 49);
    expect(timestamps(last.older), [1048, 1047, 1046, 1045, 1044]);
  });

  test("以边缘为游标继续翻页，不足一页按实际条数返回", () async {
    expect(timestamps(await repository.fetchOlderThan(1020, limit: 5)),
        [1019, 1018, 1017, 1016, 1015]);
    expect(timestamps(await repository.fetchOlderThan(1002, limit: 5)), [1001, 1000]);
    expect(await repository.fetchOlderThan(1000, limit: 5), isEmpty);

    expect(timestamps(await repository.fetchNewerThan(1047, limit: 5)), [1048, 1049]);
    expect(await repository.fetchNewerThan(1049, limit: 5), isEmpty);
  });

  test("上下文不受等级 / tag 筛选影响（相邻条目等级各异）", () async {
    final LogContext context = await repository.fetchContext(anchorAt(1025), limit: 4);
    final Set<int> levels = {
      ...context.older.map((LogModel log) => log.level),
      ...context.newer.map((LogModel log) => log.level),
    };
    expect(levels.length, greaterThan(1));
    final Set<String?> tags = {
      ...context.older.map((LogModel log) => log.tag),
      ...context.newer.map((LogModel log) => log.tag),
    };
    expect(tags, {"net", "ui"});
  });
}
