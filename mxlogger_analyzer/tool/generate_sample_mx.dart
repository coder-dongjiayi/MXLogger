import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart' as fb;

/// 生成示例 .mx 日志文件用于手动验证：
/// dart run tool/generate_sample_mx.dart [输出目录] [--key=...] [--iv=...]
/// 产出 sample_plain.mx（未加密）与 sample_encrypted.mx（默认 key=mxlogger123，iv 留空）。
///
/// key / iv 不足 16 字节时补 0x00、超出截断，与 MxBinaryParser._replenishByte 对齐；
/// iv 留空时沿用 key 作为 iv，也和解析端 MxBinaryParser._buildCrypt 的行为一致。
void main(List<String> args) {
  final List<String> positional =
      args.where((String arg) => !arg.startsWith("--")).toList();
  final Map<String, String> flags = _parseFlags(args);

  final String outputDir = positional.isNotEmpty ? positional.first : ".";
  final String cryptKey = flags["key"] ?? "zzmxlogger123";
  final String cryptIv = flags["iv"] ?? "mmmxlogger123iv";

  final int base = DateTime.now().microsecondsSinceEpoch;
  final List<Uint8List> items = [
    _record(
      name: MxBinaryParser.fileHeaderName,
      msg: jsonEncode({
        "device": "iPhone 15 Pro",
        "os": "iOS 18.2",
        "app_version": "2.3.1",
      }),
      level: 0,
      timestamp: base,
    ),
    for (int i = 0; i < _samples.length; i++)
      _record(
        name: "com.djy.app",
        tag: _samples[i].$1,
        msg: _samples[i].$3,
        level: _samples[i].$2,
        threadId: 100 + i % 3,
        isMainThread: i % 3 == 0 ? 1 : 0,
        timestamp: base + (i + 1) * 137000,
      ),
  ];

  final Uint8List plain = _buildMxFile(items);
  final Uint8List encrypted = _buildMxFile(
      items.map((item) => _encrypt(item, cryptKey, cryptIv)).toList());

  final File plainFile = File("$outputDir/sample_plain.mx")..writeAsBytesSync(plain);
  final File encryptedFile = File("$outputDir/sample_encrypted.mx")
    ..writeAsBytesSync(encrypted);

  stdout.writeln("生成完成：");
  stdout.writeln("  ${plainFile.path}（未加密，共 ${_samples.length} 条）");
  stdout.writeln("  ${encryptedFile.path}（AES-CFB 加密，key=$cryptKey，"
      "iv=${cryptIv.isEmpty ? "留空（沿用 key）" : cryptIv}）");
}

/// 只认 --name=value 形式；--name 视为开关（值为 "true"）
Map<String, String> _parseFlags(List<String> args) {
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
  return map;
}

const List<(String, int, String)> _samples = [
  ("launch", 1, "app did finish launching, cold start 412ms"),
  ("network", 0, "GET https://api.example.com/v1/user/profile"),
  ("network", 1, "GET /v1/user/profile 200 in 182ms"),
  ("db", 0, "open database user_2233.db"),
  ("auth", 2, "token will expire in 300s, schedule refresh"),
  ("network", 3, "POST /v1/order timeout after 15s (attempt 2/3)"),
  ("db", 3, "insert order failed: UNIQUE constraint failed: order.id"),
  ("ui", 0, "HomeScreen build cost 9ms"),
  ("crash", 4, "unhandled exception: NoSuchMethodError: 'total' was called on null\n#0  OrderPage.build (order_page.dart:88)\n#1  StatelessElement.build"),
  ("network", 1, "websocket connected: wss://push.example.com"),
  ("auth", 1, "refresh token success"),
  ("ui", 2, "frame drop detected: 12 frames in scroll"),
];

Uint8List _record({
  required String name,
  String tag = "",
  required String msg,
  required int level,
  int threadId = 0,
  int isMainThread = 1,
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

Uint8List _buildMxFile(List<Uint8List> items) {
  final int totalSize =
      items.fold<int>(0, (int sum, Uint8List item) => sum + 4 + item.length);
  final BytesBuilder bytes = BytesBuilder();
  bytes.add((ByteData(4)..setUint32(0, totalSize, Endian.little)).buffer.asUint8List());
  for (final Uint8List item in items) {
    bytes.add((ByteData(4)..setUint32(0, item.length, Endian.little)).buffer.asUint8List());
    bytes.add(item);
  }
  return bytes.takeBytes();
}

Uint8List _encrypt(Uint8List plain, String key, String iv) {
  final AesCrypt crypt = AesCrypt();
  // iv 留空即沿用 key（与解析端 MxBinaryParser._buildCrypt 一致）
  crypt.aesSetKeys(_keyBytes(key), _keyBytes(iv.isEmpty ? key : iv));
  crypt.aesSetMode(AesMode.cfb);
  final Uint8List padded = plain.length % 16 == 0
      ? plain
      : (Uint8List((plain.length / 16).ceil() * 16)..setRange(0, plain.length, plain));
  return Uint8List.sublistView(crypt.aesEncrypt(padded), 0, plain.length);
}

Uint8List _keyBytes(String input) {
  final Uint8List bytes = Uint8List.fromList(utf8.encode(input));
  final Uint8List result = Uint8List(16);
  result.setRange(0, min(16, bytes.length), bytes);
  return result;
}
