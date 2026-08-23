import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

List<LogRecord> records(int count, {int base = 0}) {
  return List.generate(
    count,
    (int i) => LogRecord(
      name: "Module${i % 5}",
      tag: "tag${i % 3}",
      msg: "message $i",
      level: i % 5,
      threadId: 1,
      isMainThread: 1,
      timestamp: base + i + 1,
    ),
  );
}

/// 写库分批提交会在批间让出事件循环，这些用例锁定那些让出窗口里的行为。
void main() {
  late Directory tempDir;
  late AnalyzerDatabase database;
  late HomeRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("mxlogger_concurrency");
    database = AnalyzerDatabase(tempDir.path);
    database.open();
    repository = HomeRepository(() async => database);
  });

  tearDown(() {
    database.dispose();
    tempDir.deleteSync(recursive: true);
  });

  test("批间让出时不再持有事务：并发的第二次写入不会撞 BEGIN 嵌套", () async {
    final Future<InsertSummary> first =
        database.insertRecordsWithProgress(records(3000), batchSize: 800);
    await Future<void>.delayed(Duration.zero);
    // 改为每批独立事务前，这里会抛
    // "cannot start a transaction within a transaction" 且整批 3000 条丢失
    final Future<InsertSummary> second = database
        .insertRecordsWithProgress(records(3000, base: 100000), batchSize: 800);

    expect((await first).inserted, 3000);
    expect((await second).inserted, 3000);
    expect(database.count(), 6000);
  });

  test("插入条数统计不受让出窗口内其它写操作影响", () async {
    final Future<InsertSummary> pending =
        database.insertRecordsWithProgress(records(2000), batchSize: 800);
    await Future<void>.delayed(Duration.zero);
    // 连接级 total_changes() 会把这行也算成插入，导致 duplicated 变成负数
    database.setMeta("fileName", "a.mx");

    final InsertSummary summary = await pending;
    expect(summary.inserted, 2000);
    expect(summary.duplicated, 0);
  });

  test("重复导入仍然幂等：全部记为 duplicated 且不产生新行", () async {
    final InsertSummary first =
        await database.insertRecordsWithProgress(records(1000), batchSize: 300);
    final InsertSummary second =
        await database.insertRecordsWithProgress(records(1000), batchSize: 300);

    expect(first, (inserted: 1000, duplicated: 0));
    expect(second, (inserted: 0, duplicated: 1000));
    expect(database.count(), 1000);
  });

  test("中途失败：当前批次回滚，已提交批次保留，重新导入可修复到完整", () async {
    database.insertRecords(records(10, base: 900000));

    await expectLater(
      database.insertRecordsWithProgress(
        records(2000),
        batchSize: 500,
        onProgress: (int processed, int total) {
          if (processed == 1000) throw StateError("interrupted");
        },
      ),
      throwsA(isA<StateError>()),
    );
    // 失败点在第 1000 条（第二批已提交、第三批尚未开始）
    expect(database.count(), 1010);

    // timestamp UNIQUE + OR IGNORE 让重导天然幂等：补齐缺口且不产生重复行
    final InsertSummary retry =
        await database.insertRecordsWithProgress(records(2000), batchSize: 500);
    expect(retry, (inserted: 1000, duplicated: 1000));
    expect(database.count(), 2010);
  });

  group("HomeRepository 串行闸门", () {
    test("导入期间的查询排在导入之后，读不到写了一半的数据", () async {
      final Future<void> importing = repository.replaceWith(
        results: <MxParseResult>[
          MxParseResult(records: records(4000), fileHeader: "h", errorCount: 0),
        ],
        fileName: "a.mx",
      );
      // 不 await 导入就发起查询：闸门保证它们看到的都是导入完成后的终态
      final List<Future<int>> probes = List.generate(
          5, (_) => repository.fetchLogsCount(const LogFilterState()));
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await importing;

      for (final int seen in await Future.wait(probes)) {
        expect(seen, 4000);
      }
    });

    test("导入期间的清库排在导入之后：不会删掉已提交批次造成静默错乱", () async {
      final Future<void> importing = repository.replaceWith(
        results: <MxParseResult>[
          MxParseResult(records: records(3000), fileHeader: "h", errorCount: 0),
        ],
        fileName: "a.mx",
      );
      final Future<void> clearing = repository.clearAll();
      for (int i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await importing;
      await clearing;

      // 清库整体后置：结果是「导完再清空」= 0，而不是交错出来的中间数
      expect(database.count(), 0);
    });

    test("闸门不被失败的操作卡死：后续操作照常放行", () async {
      await expectLater(
        HomeRepository(() async => throw StateError("db unavailable"))
            .fetchCount(),
        throwsA(isA<StateError>()),
      );

      database.insertRecords(records(5));
      expect(await repository.fetchCount(), 5);

      final List<LogModel> logs =
          await repository.fetchLogs(const LogFilterState());
      expect(logs.length, 5);
    });
  });
}
