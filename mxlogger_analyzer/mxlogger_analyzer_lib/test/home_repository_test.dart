import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

import 'support/mx_builder.dart';

/// 端到端：磁盘文件 → isolate 解析/解密 → 替换入库 → 条件查询。
void main() {
  late Directory tempDir;
  late AnalyzerDatabase database;
  late HomeRepository repository;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("mx_repo_test");
    database = AnalyzerDatabase(tempDir.path);
    database.open();
    repository = HomeRepository(() async => database);
  });

  tearDown(() {
    database.dispose();
    tempDir.deleteSync(recursive: true);
  });

  List<Uint8List> sampleItems(int baseTimestamp) {
    return [
      buildRecord(
        name: MxBinaryParser.fileHeaderName,
        tag: "",
        msg: "{\"device\":\"Pixel 9\",\"os\":\"Android 16\"}",
        level: 0,
        threadId: 0,
        isMainThread: 1,
        timestamp: baseTimestamp,
      ),
      buildRecord(
        name: "app",
        tag: "network",
        msg: "request start",
        level: 1,
        threadId: 8,
        isMainThread: 0,
        timestamp: baseTimestamp + 1,
      ),
      buildRecord(
        name: "app",
        tag: "db",
        msg: "query slow 1200ms",
        level: 2,
        threadId: 9,
        isMainThread: 0,
        timestamp: baseTimestamp + 2,
      ),
    ];
  }

  test("parseFiles + replaceWith：.mx 加密文件与 JSON-lines 混合", () async {
    final int base = DateTime(2026, 7, 3, 9).microsecondsSinceEpoch;
    const String key = "mxlogger123";

    final File mxFile = File("${tempDir.path}/encrypted.mx")
      ..writeAsBytesSync(buildMxFile(
        sampleItems(base).map((Uint8List item) => encryptItem(item, key, key)).toList(),
      ));
    final File jsonFile = File("${tempDir.path}/lines.log")
      ..writeAsStringSync([
        "{\"session\":\"s-1\",\"env\":\"prod\"}",
        "{\"ts\": 1751500000000, \"level\": \"info\", \"name\": \"App\", \"tags\": [\"boot\"], \"content\": \"launched\"}",
        "{\"ts\": 1751500001000, \"level\": \"fatal\", \"name\": \"Crash\", \"tags\": [\"crash\",\"native\"], \"content\": {\"code\": 11}}",
      ].join("\n"));


    // 真实解析进度：每个文件内 0→1 非递减
    final Map<int, List<double>> parseProgress = {};
    final List<ParsedFile> parsed = await repository.parseFiles(
      paths: [mxFile.path, jsonFile.path],
      cryptPairs: [MxCryptPair(key: key)],
      onProgress: (int fileIndex, double fraction) {
        parseProgress.putIfAbsent(fileIndex, () => []).add(fraction);
      },
    );
    for (final List<double> fractions in parseProgress.values) {
      expect(fractions.last, 1.0);
      for (int i = 1; i < fractions.length; i++) {
        expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
      }
    }
    expect(parsed.length, 2);
    expect(parsed[0].result, isNotNull);
    expect(parsed[0].result?.records.length, 2);
    expect(parsed[0].result?.fileHeader, contains("Pixel 9"));
    expect(parsed[1].result, isNotNull);
    expect(parsed[1].result?.records.length, 2);
    expect(parsed[1].result?.fileHeader, contains("s-1"));

    // 写库进度收敛到 1
    final List<double> insertProgress = [];
    await repository.replaceWith(
      results: parsed.map((ParsedFile f) => f.result).whereType<MxParseResult>().toList(),
      fileName: "encrypted.mx +1",
      onProgress: insertProgress.add,
    );
    expect(insertProgress.last, 1.0);

    final List<LogModel> all = await repository.fetchLogs(const LogFilterState());
    expect(all.length, 4);

    // JSON-lines 的多 tag 拆分为分词
    final List<LogModel> crash =
        await repository.fetchLogs(const LogFilterState(tags: ["native"]));
    expect(crash.length, 1);
    expect(crash.first.tags, ["crash", "native"]);
    expect(crash.first.level, 4);

    final HeaderInfo info = await repository.fetchHeaderInfo();
    expect(info.total, 4);
    expect(info.fileName, "encrypted.mx +1");
    expect(info.header["device"], "Pixel 9");
    expect(info.minUs, lessThan(info.maxUs ?? 0));

    // 再次 replaceWith 覆盖旧数据（对齐设计稿：加载即替换视图）
    await repository.replaceWith(
      results: [
        MxParseResult(records: [
          const LogRecord(
            name: "n",
            tag: "t",
            msg: "only one",
            level: 0,
            threadId: 1,
            isMainThread: 1,
            timestamp: 42,
          ),
        ]),
      ],
      fileName: "b.mx",
    );
    expect(await repository.fetchCount(), 1);
  });

  test("parseFiles：错误 key 的 .mx 判定为解析失败（result 为 null）", () async {
    final int base = DateTime(2026, 7, 3, 10).microsecondsSinceEpoch;
    final File mxFile = File("${tempDir.path}/enc.mx")
      ..writeAsBytesSync(buildMxFile(
        sampleItems(base)
            .map((Uint8List item) => encryptItem(item, "right-key", "right-key"))
            .toList(),
      ));

    final List<ParsedFile> parsed =
        await repository.parseFiles(
            paths: [mxFile.path],
            cryptPairs: const [MxCryptPair(key: "wrong-key")]);
    expect(parsed.single.result, isNull);
  });

  test("parseFiles：文件不存在抛出 IO 异常", () async {
    expect(
      () => repository.parseFiles(paths: ["${tempDir.path}/not_exist.mx"]),
      throwsA(isA<FileSystemException>()),
    );
  });
}
