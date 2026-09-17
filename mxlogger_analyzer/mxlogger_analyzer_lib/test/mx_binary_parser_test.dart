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

  // ── 长度链损坏后的重同步 ─────────────────────────────────────────────
  //
  // 真实故障：两个写入端各自持有偏移先后写进同一个 .mx，后者从前者某条记录
  // 中间开始覆盖。文件头 totalSize 指向后者的末尾，但从头顺着长度前缀走会在
  // 被覆盖的那条之后读到一个乱码长度而断掉——不重同步就只剩前面几十条。

  /// 拼出上述损坏文件：[first] 写完后，[second] 从 first 最后一条记录数据区
  /// 内 [overlapAt] 字节处开始覆盖写入；totalSize 按 second 的末尾计
  Uint8List buildOverlappedFile(
      List<Uint8List> first, List<Uint8List> second, int overlapAt) {
    final Uint8List base = buildMxFile(first);
    final int lastStart = base.length - 4 - first.last.length;
    final int secondStart = lastStart + 4 + overlapAt;
    final Uint8List tail = buildMxFile(second); // 前 4 字节是它自己的 totalSize
    final Uint8List tailItems = Uint8List.sublistView(tail, 4);
    final int fileLength = secondStart + tailItems.length;
    final Uint8List file = Uint8List(fileLength + 24); // 尾部留些 0，模拟页对齐
    file.setRange(0, base.length, base);
    file.setRange(secondStart, fileLength, tailItems);
    ByteData.sublistView(file).setUint32(0, fileLength - 4, Endian.little);
    return file;
  }

  test("重同步：后一段写入覆盖了前一段的末条，两段记录都能解出来（未加密）", () {
    final List<Uint8List> first = manyItems(6);
    final List<Uint8List> second = <Uint8List>[
      for (int i = 0; i < 5; i++)
        buildRecord(
          name: "app",
          tag: "second$i",
          msg: "second session $i",
          level: 1,
          threadId: 7,
          isMainThread: 1,
          timestamp: baseTimestamp + 1000 + i,
        ),
    ];
    final Uint8List file = buildOverlappedFile(first, second, 40);
    final MxParseResult result = MxBinaryParser.parse(file);

    expect(result.fileHeader, contains("iPhone"));
    // 前段完好的 5 条 + 后段 5 条；被覆盖的第 6 条要么解不开要么被撤掉
    expect(result.records.length, 10);
    expect(result.records.map((LogRecord r) => r.tag).take(5),
        <String>["tag0", "tag1", "tag2", "tag3", "tag4"]);
    expect(result.records.map((LogRecord r) => r.tag).skip(5),
        <String>["second0", "second1", "second2", "second3", "second4"]);
    expect(result.errorCount, greaterThanOrEqualTo(1));
  });

  test("重同步：AES-CFB 加密文件同样能跨过损坏段", () {
    const String key = "blxdfblingabckey";
    const String iv = "blbxdfblingabciv";
    final List<Uint8List> first = manyItems(6, key: key, iv: iv);
    final List<Uint8List> second = <Uint8List>[
      for (int i = 0; i < 5; i++)
        encryptItem(
          buildRecord(
            name: "app",
            tag: "second$i",
            msg: "second session $i ${"y" * (i * 13)}",
            level: 1,
            threadId: 7,
            isMainThread: 1,
            timestamp: baseTimestamp + 1000 + i,
          ),
          key,
          iv,
        ),
    ];
    final Uint8List file = buildOverlappedFile(first, second, 24);
    const List<MxCryptPair> pairs = [MxCryptPair(key: key, iv: iv)];
    final MxParseResult whole = MxBinaryParser.parse(file, cryptPairs: pairs);

    expect(whole.fileHeader, contains("iPhone"));
    expect(whole.records.length, 10);
    expect(whole.records[4].tag, "tag4");
    expect(whole.records[5].tag, "second0");
    expect(whole.records.last.tag, "second4");
    expect(whole.errorCount, greaterThanOrEqualTo(1));

    // 切段后末段接手损坏尾巴，结果与整体一致
    for (final int count in <int>[2, 3]) {
      expectSameResult(parseInChunks(file, count, cryptPairs: pairs), whole);
    }
  });

  test("重同步：损坏段之后没有任何完整记录时不臆造数据", () {
    final Uint8List file = buildMxFile(manyItems(4));
    // 把最后一条的长度前缀改成乱码，并把 totalSize 抬高到一段全 0 的尾巴之后
    final int lastStart = file.length - 4 - 60;
    final Uint8List broken = Uint8List(file.length + 200);
    broken.setRange(0, file.length, file);
    ByteData.sublistView(broken)
      ..setUint32(0, broken.length - 4, Endian.little)
      ..setUint32(lastStart, 0xdeadbeef, Endian.little);

    final MxParseResult result = MxBinaryParser.parse(broken);
    expect(result.fileHeader, contains("iPhone"));
    expect(result.records.length, lessThanOrEqualTo(4));
    for (final LogRecord record in result.records) {
      expect(record.tag, startsWith("tag"));
    }
    expect(result.errorCount, greaterThanOrEqualTo(1));
  });
}
