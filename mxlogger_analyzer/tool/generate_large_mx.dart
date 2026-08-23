import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart' as fb;

/// 生成大体量 .mx 日志文件，用于实测导入/查询性能。
///
/// 条数是唯一的体积驱动：给多少条就生成多少条，单条长度由日志内容自然决定，
/// 最终体积作为结果打印出来（不去凑某个目标体积）。
///
/// ```
/// dart run tool/generate_large_mx.dart                       # 默认 77 万条
/// dart run tool/generate_large_mx.dart --records=1000000     # 100 万条
/// dart run tool/generate_large_mx.dart --key=... --iv=... --out=/tmp/big.mx
/// dart run tool/generate_large_mx.dart --plain               # 不加密，对比解密开销
/// ```
///
/// KEY / IV 必须都是 16 字节（与写入端 AES-128 对齐），不足或超出直接报错，
/// 不做静默补齐——压测数据的解密参数必须和线上一致才有意义。
///
/// 与 tool/generate_sample_mx.dart 的区别：那个产出体积极小的功能样例，
/// 这个专为压测设计——流式写盘（不在内存里攒整个文件）、内容分布覆盖各个
/// 筛选维度，并打印可直接用于校验的期望值。
void main(List<String> args) {
  final _Options options;
  try {
    options = _Options.parse(args);
  } on FormatException catch (error) {
    stderr.writeln("参数错误：${error.message}");
    exit(64);
  }

  final Stopwatch sw = Stopwatch()..start();

  // 文件头（首条且 name 为约定值时被解析器识别为环境信息，不计入日志条数）
  final Uint8List header = _record(
    name: MxBinaryParser.fileHeaderName,
    tag: "",
    msg: jsonEncode(<String, String>{
      "device": "iPhone 15 Pro",
      "os": "iOS 18.2",
      "app_version": "2.3.1",
      "generated_by": "tool/generate_large_mx.dart",
      "records": "${options.records}",
    }),
    level: 0,
    threadId: 0,
    isMainThread: 1,
    timestamp: options.baseTimestamp,
  );

  final RandomAccessFile file =
      File(options.output).openSync(mode: FileMode.write);
  // totalSize 需要写在最前面但只有写完才知道，先占位、收尾时回填
  file.writeFromSync(_uint32(0));

  final _Writer writer = _Writer(file);
  final _Encryptor? encryptor =
      options.plain ? null : _Encryptor(options.key, options.iv);
  final Random random = Random(options.seed);

  int totalSize = 0;
  totalSize += writer.writeItem(encryptor == null ? header : encryptor.run(header));

  final Map<int, int> levelCounts = <int, int>{};
  int rareHits = 0;
  int midHits = 0;
  int stackHits = 0;
  int msgBytes = 0;
  int lastTimestamp = options.baseTimestamp;

  for (int i = 0; i < options.records; i++) {
    final int level = _pickLevel(random);
    levelCounts[level] = (levelCounts[level] ?? 0) + 1;

    // 时间戳严格递增：db 以 timestamp UNIQUE 去重，重复会被 OR IGNORE 丢掉，
    // 那样实际入库条数就对不上，压测数据必须保证唯一
    lastTimestamp += 1 + random.nextInt(options.stepUs);

    String msg = _message(random, level);
    // 已知频次的检索哨兵：导入后可直接用它们验证搜索命中数
    if (i % 100000 == 0) {
      msg = "$msg SENTINEL_RARE";
      rareHits++;
    } else if (i % 1000 == 0) {
      msg = "$msg SENTINEL_MID";
      midHits++;
    }
    if (msg.contains("\n")) stackHits++;
    msgBytes += utf8.encode(msg).length;

    final Uint8List item = _record(
      name: _names[random.nextInt(_names.length)],
      tag: _tags[random.nextInt(_tags.length)],
      msg: msg,
      level: level,
      threadId: 1000 + random.nextInt(8),
      isMainThread: random.nextInt(4) == 0 ? 1 : 0,
      timestamp: lastTimestamp,
    );

    totalSize += writer.writeItem(encryptor == null ? item : encryptor.run(item));

    if ((i + 1) % 50000 == 0) {
      stdout.writeln("  ${i + 1} / ${options.records} 条"
          "  ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MiB"
          "  ${sw.elapsed.inSeconds}s");
    }
  }

  writer.flush();
  // 回填 totalSize：解析器以 begin <= totalSize 作为循环边界，写错会截断日志
  file.setPositionSync(0);
  file.writeFromSync(_uint32(totalSize));
  file.closeSync();
  sw.stop();

  final int actual = File(options.output).lengthSync();
  final Duration span =
      Duration(microseconds: lastTimestamp - options.baseTimestamp);
  stdout.writeln("");
  stdout.writeln("生成完成：${options.output}");
  stdout.writeln("  日志条数   ${options.records}（另有 1 条文件头，不计入日志）");
  stdout.writeln("  体积       ${(actual / 1024 / 1024).toStringAsFixed(1)} MiB"
      "（$actual 字节）");
  stdout.writeln("  平均单条   ${(totalSize / (options.records + 1)).toStringAsFixed(1)} 字节"
      "（其中 msg 平均 ${(msgBytes / options.records).toStringAsFixed(1)} 字节）");
  if (options.plain) {
    stdout.writeln("  加密       无（明文）");
  } else {
    stdout.writeln("  加密       AES-CFB(128)");
    stdout.writeln("  KEY        ${options.key}   (${options.key.length} 字节)");
    stdout.writeln("  IV         ${options.iv}   (${options.iv.length} 字节)");
  }
  stdout.writeln("  耗时       ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s");
  stdout.writeln("");
  stdout.writeln("导入后可据此校验：");
  final List<int> levels = levelCounts.keys.toList()..sort();
  for (final int level in levels) {
    stdout.writeln("  level $level        ${levelCounts[level]} 条");
  }
  stdout.writeln("  name 去重    ${_names.length} 个");
  stdout.writeln("  tag 去重     ${_distinctTags().length} 个（tag 列含逗号/空格多值）");
  stdout.writeln("  时间跨度     ${span.inHours}h${span.inMinutes % 60}m");
  stdout.writeln("  搜索 SENTINEL_RARE  应命中 $rareHits 条");
  stdout.writeln("  搜索 SENTINEL_MID   应命中 $midHits 条");
  stdout.writeln("  含多行堆栈           $stackHits 条");
}

/// 命令行参数
class _Options {
  _Options({
    required this.output,
    required this.records,
    required this.key,
    required this.iv,
    required this.plain,
    required this.seed,
    required this.baseTimestamp,
    required this.stepUs,
  });

  /// AES-128：KEY / IV 都必须是 16 字节
  static const int keyLength = 16;

  factory _Options.parse(List<String> args) {
    final Map<String, String> map = <String, String>{};
    for (final String arg in args) {
      if (!arg.startsWith("--")) continue;
      final int eq = arg.indexOf("=");
      if (eq < 0) {
        map[arg.substring(2)] = "true";
      } else {
        map[arg.substring(2, eq)] = arg.substring(eq + 1);
      }
    }

    final int records = int.parse(map["records"] ?? "770000");
    if (records <= 0) throw const FormatException("--records 必须大于 0");

    final bool plain = map["plain"] == "true";
    final String key = map["key"] ?? "mxlogger_key_123";
    final String iv = map["iv"] ?? "mxlogger_iv_4567";
    if (!plain) {
      _checkLength("KEY", key);
      _checkLength("IV", iv);
    }

    // 固定基准时间戳（不取 now）：同样参数两次运行产出完全一致的文件，
    // 压测结果才可比
    final int base = int.parse(map["base"] ?? "1735689600000000");
    return _Options(
      output: map["out"] ?? "mxlogger_${records}_records.mx",
      records: records,
      key: key,
      iv: iv,
      plain: plain,
      seed: int.parse(map["seed"] ?? "20260823"),
      baseTimestamp: base,
      // 不论条数多少，都把日志铺开到约 6 小时
      stepUs: max(2, 6 * 3600 * 1000000 ~/ records * 2),
    );
  }

  /// 不做静默补齐：写入端是定长 16 字节，长度不对就该在这里报错，
  /// 否则生成的文件用线上参数解不开，压测就白做了
  static void _checkLength(String label, String value) {
    final int length = utf8.encode(value).length;
    if (length != keyLength) {
      throw FormatException(
          "$label 必须是 $keyLength 字节，当前 \"$value\" 为 $length 字节");
    }
  }

  final String output;
  final int records;
  final String key;
  final String iv;
  final bool plain;
  final int seed;
  final int baseTimestamp;
  final int stepUs;
}

/// 带缓冲的流式写入：攒够一块再落盘，避免上百万次系统调用，
/// 也避免把整个文件攒在内存里
class _Writer {
  _Writer(this._file);

  static const int _flushAt = 8 * 1024 * 1024;

  final RandomAccessFile _file;
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// 写入一个 item（4 字节长度前缀 + 内容），返回它占用的字节数
  int writeItem(Uint8List item) {
    _buffer.add(_uint32(item.length));
    _buffer.add(item);
    if (_buffer.length >= _flushAt) flush();
    return 4 + item.length;
  }

  void flush() {
    if (_buffer.isEmpty) return;
    _file.writeFromSync(_buffer.takeBytes());
  }
}

/// AES-CFB(128) 逐条加密，KEY / IV 定长 16 字节（长度已在参数解析阶段校验）
class _Encryptor {
  _Encryptor(String key, String iv) {
    _crypt.aesSetKeys(
      Uint8List.fromList(utf8.encode(key)),
      Uint8List.fromList(utf8.encode(iv)),
    );
    _crypt.aesSetMode(AesMode.cfb);
  }

  final AesCrypt _crypt = AesCrypt();

  Uint8List run(Uint8List plain) {
    // CFB 按块加密，先补齐到 16 的整数倍，再按原长截断密文
    // （解析端 _replenishDataByte 会做同样的补齐）
    final Uint8List padded = plain.length % 16 == 0
        ? plain
        : (Uint8List((plain.length / 16).ceil() * 16)
          ..setRange(0, plain.length, plain));
    return Uint8List.sublistView(_crypt.aesEncrypt(padded), 0, plain.length);
  }
}

Uint8List _record({
  required String name,
  required String tag,
  required String msg,
  required int level,
  required int threadId,
  required int isMainThread,
  required int timestamp,
}) {
  final fb.Builder builder = fb.Builder();
  final int nameOffset = builder.writeString(name);
  final int tagOffset = builder.writeString(tag);
  final int msgOffset = builder.writeString(msg);
  final LogSerializeBuilder logBuilder = LogSerializeBuilder(builder);
  logBuilder.begin();
  logBuilder.addNameOffset(nameOffset);
  logBuilder.addTagOffset(tagOffset);
  logBuilder.addMsgOffset(msgOffset);
  logBuilder.addLevel(level);
  logBuilder.addThreadId(threadId);
  logBuilder.addIsMainThread(isMainThread);
  logBuilder.addTimestamp(timestamp);
  builder.finish(logBuilder.finish());
  return builder.buffer;
}

Uint8List _uint32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

/// 等级分布贴近真实 app：info/debug 占多数，error/fatal 少量
int _pickLevel(Random random) {
  final int roll = random.nextInt(100);
  if (roll < 34) return 0;
  if (roll < 68) return 1;
  if (roll < 86) return 2;
  if (roll < 98) return 3;
  return 4;
}

/// 消息长度不做统一，按真实日志的形态分层：多数是一句话，
/// 一部分带上下文键值对，少数带 payload 摘要，level 4 追加多行堆栈。
/// 长度自然参差，LIKE 检索的选择性才不会失真。
String _message(Random random, int level) {
  final StringBuffer buffer = StringBuffer(_template(random, level));
  final int roll = random.nextInt(100);
  if (roll >= 60 && roll < 85) {
    final int fields = 1 + random.nextInt(3);
    for (int i = 0; i < fields; i++) {
      buffer.write(" ${_contextKeys[random.nextInt(_contextKeys.length)]}"
          "=${random.nextInt(99999)}");
    }
  } else if (roll >= 85 && roll < 97) {
    buffer.write(' payload={"uid":${100000 + random.nextInt(899999)},'
        '"trace":"${_hex(random, 16)}",'
        '"items":${random.nextInt(50)},"cost_ms":${random.nextInt(2000)}}');
  }
  if (level == 4) buffer.write("\n${_stackTrace(random)}");
  return buffer.toString();
}

const List<String> _contextKeys = <String>[
  "uid", "seq", "cost_ms", "retry", "size", "code", "conn_id", "offset",
];

String _hex(Random random, int length) {
  const String chars = "0123456789abcdef";
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i++) {
    buffer.write(chars[random.nextInt(16)]);
  }
  return buffer.toString();
}

const List<String> _names = <String>[
  "com.djy.app.launch",
  "com.djy.app.network",
  "com.djy.app.database",
  "com.djy.app.auth",
  "com.djy.app.player",
  "com.djy.app.ui",
  "com.djy.app.push",
  "com.djy.app.payment",
  "com.djy.app.upload",
  "com.djy.app.cache",
  "com.djy.app.location",
  "com.djy.app.analytics",
];

/// 含单值与逗号/空格多值：解析器按 [,\s]+ 分词，用来验证 tag 联想与筛选
const List<String> _tags = <String>[
  "network",
  "db",
  "auth",
  "ui",
  "player",
  "upload",
  "network,retry",
  "db,slow",
  "auth token",
  "ui,jank",
  "payment,risk",
  "cache,evict",
  "",
];

Set<String> _distinctTags() {
  final Set<String> tags = <String>{};
  for (final String raw in _tags) {
    for (final String tag in raw.split(RegExp(r"[,\s]+"))) {
      if (tag.isNotEmpty) tags.add(tag);
    }
  }
  return tags;
}

String _template(Random random, int level) {
  final List<String> pool = _messages[level] ?? _messages[0]!;
  return pool[random.nextInt(pool.length)];
}

const Map<int, List<String>> _messages = <int, List<String>>{
  0: <String>[
    "GET https://api.example.com/v1/user/profile prepared",
    "open database user_2233.db, journal=wal",
    "HomeScreen build cost 9ms",
    "cache lookup hit ratio 0.82",
    "location update accuracy=12.4m provider=gps",
  ],
  1: <String>[
    "GET /v1/user/profile 200 in 182ms",
    "refresh token success",
    "websocket connected: wss://push.example.com",
    "upload finished part 3/5, speed=1.8MB/s",
    "player prepared, duration=1830s bitrate=1200kbps",
  ],
  2: <String>[
    "token will expire in 300s, schedule refresh",
    "frame drop detected: 12 frames during scroll",
    "slow query took 412ms: SELECT * FROM orders WHERE status=?",
    "cache eviction pressure, dropped 128 entries",
    "retrying upload part 4/5 after 503",
  ],
  3: <String>[
    "POST /v1/order timeout after 15s (attempt 2/3)",
    "insert order failed: UNIQUE constraint failed: order.id",
    "payment risk check rejected, code=RISK_3021",
    "push registration failed: APNs 400 BadDeviceToken",
    "websocket closed abnormally, code=1006 reconnect in 3s",
  ],
  4: <String>[
    "unhandled exception: NoSuchMethodError: 'total' was called on null",
    "fatal: database disk image is malformed",
    "OOM: allocation of 48MB failed, resident=1.2GB",
  ],
};

String _stackTrace(Random random) {
  final int line = 40 + random.nextInt(400);
  return "#0  OrderPage.build (package:app/order/order_page.dart:$line:14)\n"
      "#1  StatelessElement.build (package:flutter/src/widgets/framework.dart:5083:49)\n"
      "#2  ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:4996:15)";
}
