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

  // ── 分段并行解密（ParseIsolate 大文件走这条路径）─────────────────────
  //
  // 并行的正确性前提是「切段不改变解析结果」：段内记录顺序、跨段拼回的
  // 总顺序、fileHeader 归属、errorCount 累计都必须与整体解析逐项一致。

  List<Uint8List> manyItems(int count, {String? key, String? iv}) {
    Uint8List wrap(Uint8List item) =>
        key == null ? item : encryptItem(item, key, iv ?? key);
    return [
      wrap(buildRecord(
        name: MxBinaryParser.fileHeaderName,
        tag: "",
        msg: "{\"device\":\"iPhone\"}",
        level: 0,
        threadId: 0,
        isMainThread: 1,
        timestamp: baseTimestamp,
      )),
      for (int i = 0; i < count; i++)
        wrap(buildRecord(
          name: "app",
          tag: "tag$i",
          msg: "message $i padded ${"x" * (i % 40)}",
          level: i % 5,
          threadId: 1000 + i % 4,
          isMainThread: i % 2,
          timestamp: baseTimestamp + 1 + i,
        )),
    ];
  }

  /// 按 [count] 段切开后逐段解析再拼回，模拟 ParseIsolate 的并行合并
  MxParseResult parseInChunks(Uint8List file, int count,
      {List<MxCryptPair> cryptPairs = const <MxCryptPair>[]}) {
    final List<({int start, int end})> ranges =
        MxBinaryParser.splitRanges(file, count);
    final List<LogRecord> records = [];
    String? fileHeader;
    int errorCount = 0;
    for (int i = 0; i < ranges.length; i++) {
      final MxParseResult part = MxBinaryParser.parseChunk(
        file.sublist(ranges[i].start, ranges[i].end),
        allowFileHeader: i == 0,
        cryptPairs: cryptPairs,
      );
      records.addAll(part.records);
      fileHeader ??= part.fileHeader;
      errorCount = errorCount + part.errorCount;
    }
    return MxParseResult(
        records: records, fileHeader: fileHeader, errorCount: errorCount);
  }

  void expectSameResult(MxParseResult actual, MxParseResult expected) {
    expect(actual.fileHeader, expected.fileHeader);
    expect(actual.errorCount, expected.errorCount);
    expect(actual.records.length, expected.records.length);
    for (int i = 0; i < expected.records.length; i++) {
      final LogRecord a = actual.records[i];
      final LogRecord b = expected.records[i];
      expect(a.timestamp, b.timestamp, reason: "第 $i 条顺序或内容不一致");
      expect(a.msg, b.msg);
      expect(a.name, b.name);
      expect(a.tag, b.tag);
      expect(a.level, b.level);
      expect(a.threadId, b.threadId);
      expect(a.isMainThread, b.isMainThread);
    }
  }

  test("切段解析与整体解析等价（未加密）", () {
    final Uint8List file = buildMxFile(manyItems(60));
    final MxParseResult whole = MxBinaryParser.parse(file);
    expect(whole.records.length, 60);

    for (final int count in <int>[2, 3, 4, 8]) {
      expectSameResult(parseInChunks(file, count), whole);
    }
  });

  test("切段解析与整体解析等价（AES-CFB 加密）", () {
    const String key = "mxlogger_key_123";
    const String iv = "mxlogger_iv_4567";
    final Uint8List file = buildMxFile(manyItems(60, key: key, iv: iv));
    const List<MxCryptPair> pairs = [MxCryptPair(key: key, iv: iv)];
    final MxParseResult whole = MxBinaryParser.parse(file, cryptPairs: pairs);
    expect(whole.records.length, 60);
    expect(whole.errorCount, 0);

    for (final int count in <int>[2, 3, 5, 8]) {
      expectSameResult(parseInChunks(file, count, cryptPairs: pairs), whole);
    }
  });

  test("切段：段两两相接、覆盖全部有效数据、不切断记录", () {
    final Uint8List file = buildMxFile(manyItems(60));
    final List<({int start, int end})> ranges =
        MxBinaryParser.splitRanges(file, 4);

    expect(ranges.length, 4);
    // 首段从 totalSize 之后开始，段尾接下一段段首，末段收在文件末尾
    expect(ranges.first.start, 4);
    expect(ranges.last.end, file.length);
    for (int i = 1; i < ranges.length; i++) {
      expect(ranges[i].start, ranges[i - 1].end);
    }
    // 每段单独解析都不该有解析失败——切在记录中间才会
    for (int i = 0; i < ranges.length; i++) {
      final MxParseResult part = MxBinaryParser.parseChunk(
          file.sublist(ranges[i].start, ranges[i].end),
          allowFileHeader: i == 0);
      expect(part.errorCount, 0, reason: "第 $i 段被切断了");
    }
  });

  test("切段：段数超过记录数时不产生空段", () {
    final Uint8List file = buildMxFile(manyItems(2));
    final List<({int start, int end})> ranges =
        MxBinaryParser.splitRanges(file, 16);

    expect(ranges.length, lessThanOrEqualTo(3));
    for (final ({int start, int end}) range in ranges) {
      expect(range.end, greaterThan(range.start));
    }
    expectSameResult(parseInChunks(file, 16), MxBinaryParser.parse(file));
  });

  test("只有段 0 认文件头：其余段的同名记录算普通日志", () {
    final Uint8List file = buildMxFile(manyItems(20));
    final List<({int start, int end})> ranges =
        MxBinaryParser.splitRanges(file, 2);
    // 段 0 首条就是文件头
    final MxParseResult first = MxBinaryParser.parseChunk(
        file.sublist(ranges[0].start, ranges[0].end),
        allowFileHeader: true);
    expect(first.fileHeader, contains("iPhone"));

    // 同一段字节改判为非首段时，那条不再被吃掉，而是当普通记录返回
    final MxParseResult asLater = MxBinaryParser.parseChunk(
        file.sublist(ranges[0].start, ranges[0].end),
        allowFileHeader: false);
    expect(asLater.fileHeader, isNull);
    expect(asLater.records.length, first.records.length + 1);
    expect(asLater.records.first.name, MxBinaryParser.fileHeaderName);
  });

  test("切段：空文件与截断数据返回空段，不崩溃", () {
    expect(MxBinaryParser.splitRanges(Uint8List(0), 4), isEmpty);
    expect(MxBinaryParser.splitRanges(Uint8List.fromList([1, 0]), 4), isEmpty);
    expect(MxBinaryParser.splitRanges(buildMxFile(manyItems(4)), 0), isEmpty);

    // 截断到一半：只切出仍然完整的记录，逐段解析不越界
    final Uint8List file = buildMxFile(manyItems(30));
    final Uint8List truncated =
        Uint8List.sublistView(file, 0, file.length ~/ 2);
    expectSameResult(
        parseInChunks(truncated, 4), MxBinaryParser.parse(truncated));
  });
}
