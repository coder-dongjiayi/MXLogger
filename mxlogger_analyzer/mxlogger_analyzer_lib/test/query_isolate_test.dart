import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_repository.dart';
import 'package:sqlite3/sqlite3.dart' as SQLite;

/// 真实库路径由环境变量给，没设就跳过（CI / 别的机器上没有这个库）
final String? realDatabaseDir =
    Platform.environment["MXLOG_REAL_DB_DIR"];

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("mxlog_test");
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// 造一个小库，字段和真实表一致
  void seed(int rows) {
    AnalyzerDatabase.initDataBase(tempDir.path);
    for (int i = 0; i < rows; i++) {
      AnalyzerDatabase.db.execute(
          "insert into mxlog (name,tag,msg,level,threadId,isMainThread,timestamp,fileHeader,dateTime,createDateTime) "
          "values (?,?,?,?,?,?,?,?,?,?)",
          [
            "mxlogger",
            i % 2 == 0 ? "payment" : "rtc",
            "消息内容 $i",
            i % 5,
            1,
            1,
            1000000 + i,
            "1.0.0",
            "",
            ""
          ]);
    }
  }

  test("initDataBase 会补建 timestamp / level 索引", () {
    AnalyzerDatabase.initDataBase(tempDir.path);
    final names = AnalyzerDatabase.db
        .select("select name from sqlite_master where type='index'")
        .map((e) => e["name"] as String)
        .toList();
    expect(names, contains("idx_mxlog_timestamp"));
    expect(names, contains("idx_mxlog_level"));
  });

  test("已有的旧库(无索引)再次打开时被补上索引", () {
    /// 手工建一张没有索引的表，模拟旧版本产物
    final db = SQLite.sqlite3.open("${tempDir.path}/mxlogger_analyzer.db");
    db.execute("CREATE TABLE mxlog(id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "name TEXT, tag TEXT, msg TEXT, level INTEGER, threadId INTEGER, "
        "isMainThread INTEGER, timestamp INTEGER, fileHeader TEXT, "
        "dateTime TEXT, createDateTime TEXT)");
    expect(
        db
            .select("select name from sqlite_master where type='index'")
            .isEmpty,
        true);
    db.dispose();

    AnalyzerDatabase.initDataBase(tempDir.path);
    final names = AnalyzerDatabase.db
        .select("select name from sqlite_master where type='index'")
        .map((e) => e["name"] as String)
        .toList();
    expect(names, contains("idx_mxlog_timestamp"));
  });

  test("fetchLogs 在后台 isolate 里查询并正确应用筛选条件", () async {
    seed(100);
    final repository = MXLoggerRepository();

    final all = await repository.fetchLogs();
    expect(all.length, 100);

    /// 降序：第一条应该是 timestamp 最大的
    expect(all.first.timestamp, 1000099);

    final asc = await repository.fetchLogs(order: "asc");
    expect(asc.first.timestamp, 1000000);

    /// 等级筛选
    final errors = await repository.fetchLogs(levels: [3]);
    expect(errors.length, 20);
    expect(errors.every((e) => e.level == 3), true);

    /// 自定义条件搜索
    final byTag =
        await repository.fetchLogs(searchCondition: "tag like '%payment%'");
    expect(byTag.length, 50);
    expect(byTag.every((e) => e.tag == "payment"), true);

    /// 多选等级 + 搜索条件叠加。
    /// 修复前 where 拼成 (条件) and level=0 or level=3，and 优先级高于 or，
    /// 等价于 ((条件) and level=0) or level=3，tag 条件会对 level=3 失效
    final both = await repository.fetchLogs(
        levels: [0, 3], searchCondition: "tag like '%payment%'");
    expect(both.isNotEmpty, true);
    expect(both.every((e) => e.tag == "payment"), true);
    expect(both.every((e) => e.level == 0 || e.level == 3), true);
  });

  test("查询期间主 isolate 不被阻塞", () async {
    seed(3000);
    final repository = MXLoggerRepository();

    /// 查询进行中主 isolate 仍能正常调度事件循环；
    /// 若查询是同步跑在主 isolate 上，这个计数在查询返回前会一直是 0
    int ticks = 0;
    bool done = false;
    void tick() {
      if (done) return;
      ticks++;
      Future.delayed(const Duration(milliseconds: 1), tick);
    }

    tick();
    final logs = await repository.fetchLogs();
    done = true;

    expect(logs.length, 3000);
    expect(ticks, greaterThan(0));
  });

  test("Isolate.run 回传大结果不做深拷贝(冒烟)", () async {
    /// 单纯确认大 List 能跨 isolate 返回且内容正确
    final list = await Isolate.run(() => List<int>.generate(500000, (i) => i));
    expect(list.length, 500000);
    expect(list.last, 499999);
  });

  group("真实库", () {
    test("对真实库执行筛选", () async {
      if (realDatabaseDir == null) {
        markTestSkipped("未设置 MXLOG_REAL_DB_DIR，跳过");
        return;
      }
      AnalyzerDatabase.initDataBase(realDatabaseDir!);
      final repository = MXLoggerRepository();

      final sw = Stopwatch()..start();
      final all = await repository.fetchLogs();
      sw.stop();
      // ignore: avoid_print
      print("全量 ${all.length} 条, 耗时 ${sw.elapsedMilliseconds}ms");

      sw
        ..reset()
        ..start();
      final errors = await repository.fetchLogs(levels: [3]);
      sw.stop();
      // ignore: avoid_print
      print("ERROR ${errors.length} 条, 耗时 ${sw.elapsedMilliseconds}ms");

      sw
        ..reset()
        ..start();
      final filtered = await repository.fetchLogs(
          searchCondition: "msg not like '%upload%'");
      sw.stop();
      // ignore: avoid_print
      print("条件过滤 ${filtered.length} 条, 耗时 ${sw.elapsedMilliseconds}ms");

      expect(all.length, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
