import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

import 'support/mx_builder.dart';

void main() {
  final int baseTimestamp = DateTime(2026, 7, 3, 10, 30, 15).microsecondsSinceEpoch;

  List<Uint8List> sampleItems() {
    return [
      buildRecord(
        name: MxBinaryParser.fileHeaderName,
        tag: "",
        msg: "{\"device\":\"iPhone\",\"app_version\":\"1.0.0\"}",
        level: 0,
        threadId: 0,
        isMainThread: 1,
        timestamp: baseTimestamp,
      ),
      buildRecord(
        name: "app",
        tag: "network",
        msg: "GET /api/user 200",
        level: 1,
        threadId: 1001,
        isMainThread: 0,
        timestamp: baseTimestamp + 1,
      ),
      buildRecord(
        name: "app",
        tag: "db",
        msg: "insert failed: constraint",
        level: 3,
        threadId: 1,
        isMainThread: 1,
        timestamp: baseTimestamp + 2,
      ),
    ];
  }

  test("解析未加密 .mx：fileHeader 提取 + 字段完整往返", () {
    final Uint8List file = buildMxFile(sampleItems());
    final MxParseResult result = MxBinaryParser.parse(file);

    expect(result.fileHeader, contains("iPhone"));
    expect(result.errorCount, 0);
    expect(result.records.length, 2);

    final LogRecord first = result.records[0];
    expect(first.name, "app");
    expect(first.tag, "network");
    expect(first.msg, "GET /api/user 200");
    expect(first.level, 1);
    expect(first.threadId, 1001);
    expect(first.isMainThread, 0);
    expect(first.timestamp, baseTimestamp + 1);

    expect(result.records[1].level, 3);
    expect(result.records[1].msg, "insert failed: constraint");
  });

  test("解析 AES-CFB 加密 .mx：iv 缺省回退为 key", () {
    const String key = "abc123";
    final List<Uint8List> encrypted =
        sampleItems().map((Uint8List item) => encryptItem(item, key, key)).toList();
    final Uint8List file = buildMxFile(encrypted);

    final MxParseResult result = MxBinaryParser.parse(file, cryptKey: key);

    expect(result.fileHeader, contains("iPhone"));
    expect(result.errorCount, 0);
    expect(result.records.length, 2);
    expect(result.records[0].msg, "GET /api/user 200");
    expect(result.records[1].timestamp, baseTimestamp + 2);
  });

  test("解析 AES-CFB 加密 .mx：显式 iv 与 key 不同", () {
    const String key = "keykey";
    const String iv = "iviviv";
    final List<Uint8List> encrypted =
        sampleItems().map((Uint8List item) => encryptItem(item, key, iv)).toList();
    final Uint8List file = buildMxFile(encrypted);

    final MxParseResult result = MxBinaryParser.parse(file, cryptKey: key, iv: iv);
    expect(result.errorCount, 0);
    expect(result.records.length, 2);
    expect(result.records[0].tag, "network");
  });

  test("错误的 key 解不出数据，全部计入 errorCount", () {
    const String key = "correct-key";
    final List<Uint8List> encrypted =
        sampleItems().map((Uint8List item) => encryptItem(item, key, key)).toList();
    final Uint8List file = buildMxFile(encrypted);

    final MxParseResult result = MxBinaryParser.parse(file, cryptKey: "wrong-key");
    expect(result.records, isEmpty);
    expect(result.errorCount, 3);
  });

  test("多组候选：第一组解不开自动换下一组", () {
    const String key = "second-key";
    const String iv = "second-iv";
    final Uint8List file = buildMxFile(
      sampleItems().map((Uint8List item) => encryptItem(item, key, iv)).toList(),
    );

    final MxParseResult result = MxBinaryParser.parse(file, cryptPairs: const [
      MxCryptPair(key: "wrong-key", iv: "wrong-iv"),
      MxCryptPair(key: key, iv: iv),
      MxCryptPair(key: "never-used"),
    ]);

    expect(result.errorCount, 0);
    expect(result.records.length, 2);
    expect(result.records[0].msg, "GET /api/user 200");
    expect(result.fileHeader, contains("iPhone"));
  });

  test("同一文件内混用两组 Key/IV：逐条回退，全部解得出来", () {
    // 写入端中途换了密钥，新旧日志追加在同一个文件里
    final List<Uint8List> items = sampleItems();
    final Uint8List file = buildMxFile([
      encryptItem(items[0], "old-key", "old-iv"),
      encryptItem(items[1], "old-key", "old-iv"),
      encryptItem(items[2], "new-key", "new-iv"),
    ]);

    final MxParseResult result = MxBinaryParser.parse(file, cryptPairs: const [
      MxCryptPair(key: "old-key", iv: "old-iv"),
      MxCryptPair(key: "new-key", iv: "new-iv"),
    ]);

    expect(result.errorCount, 0);
    expect(result.fileHeader, contains("iPhone"));
    expect(result.records.length, 2);
    expect(result.records[0].msg, "GET /api/user 200");
    expect(result.records[1].msg, "insert failed: constraint");
  });

  test("同一文件内混用两组 Key/IV：只勾了其中一组时另一组的记录算解析失败", () {
    final List<Uint8List> items = sampleItems();
    final Uint8List file = buildMxFile([
      encryptItem(items[0], "old-key", "old-iv"),
      encryptItem(items[1], "old-key", "old-iv"),
      encryptItem(items[2], "new-key", "new-iv"),
    ]);

    final MxParseResult result = MxBinaryParser.parse(
      file,
      cryptPairs: const [MxCryptPair(key: "old-key", iv: "old-iv")],
    );
    expect(result.records.length, 1);
    expect(result.records[0].msg, "GET /api/user 200");
    expect(result.errorCount, 1);
  });

  test("多组候选：命中的那组优先于后面的组", () {
    const String key = "first-key";
    final Uint8List file = buildMxFile(
      sampleItems().map((Uint8List item) => encryptItem(item, key, key)).toList(),
    );

    final MxParseResult result = MxBinaryParser.parse(file, cryptPairs: const [
      MxCryptPair(key: key),
      MxCryptPair(key: "another-key"),
    ]);
    expect(result.errorCount, 0);
    expect(result.records.length, 2);
  });

  test("多组候选全不匹配：解不出数据（与单组错误 key 行为一致）", () {
    final Uint8List file = buildMxFile(
      sampleItems()
          .map((Uint8List item) => encryptItem(item, "real-key", "real-key"))
          .toList(),
    );

    final MxParseResult result = MxBinaryParser.parse(file, cryptPairs: const [
      MxCryptPair(key: "wrong-1"),
      MxCryptPair(key: "wrong-2"),
    ]);
    expect(result.records, isEmpty);
    expect(result.errorCount, 3);
  });

  test("空文件与截断数据不崩溃", () {
    expect(MxBinaryParser.parse(Uint8List(0)).records, isEmpty);
    expect(MxBinaryParser.parse(Uint8List.fromList([1, 0])).records, isEmpty);

    final Uint8List file = buildMxFile(sampleItems());
    // 截断到一半：解析已完整的条目，不越界
    final Uint8List truncated = Uint8List.sublistView(file, 0, file.length ~/ 2);
    final MxParseResult result = MxBinaryParser.parse(truncated);
    expect(result.records.length, lessThan(2));
  });
}
