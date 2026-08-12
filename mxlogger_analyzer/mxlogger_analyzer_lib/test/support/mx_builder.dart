import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart' as fb;

/// 测试共享：模拟 MXLogger native 写入端构造 .mx 二进制。
Uint8List buildRecord({
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

/// 按 .mx 布局拼文件：[uint32 totalSize][uint32 itemSize][item]...（小端）
Uint8List buildMxFile(List<Uint8List> items) {
  final int totalSize =
      items.fold<int>(0, (int sum, Uint8List item) => sum + 4 + item.length);
  final BytesBuilder bytes = BytesBuilder();
  final ByteData header = ByteData(4)..setUint32(0, totalSize, Endian.little);
  bytes.add(header.buffer.asUint8List());
  for (final Uint8List item in items) {
    final ByteData itemHeader = ByteData(4)..setUint32(0, item.length, Endian.little);
    bytes.add(itemHeader.buffer.asUint8List());
    bytes.add(item);
  }
  return bytes.takeBytes();
}

/// CFB 流式特性：加密补零明文后截取原长度，即等价于 native 端原长度密文
Uint8List encryptItem(Uint8List plain, String key, String iv) {
  final AesCrypt crypt = AesCrypt();
  crypt.aesSetKeys(keyBytes(key), keyBytes(iv));
  crypt.aesSetMode(AesMode.cfb);
  final Uint8List encrypted = crypt.aesEncrypt(padTo16(plain));
  return Uint8List.sublistView(encrypted, 0, plain.length);
}

Uint8List padTo16(Uint8List input) {
  if (input.length % 16 == 0) return input;
  final Uint8List result = Uint8List((input.length / 16).ceil() * 16);
  result.setRange(0, input.length, input);
  return result;
}

Uint8List keyBytes(String input) {
  final Uint8List bytes = Uint8List.fromList(utf8.encode(input));
  final Uint8List result = Uint8List(16);
  result.setRange(0, min(16, bytes.length), bytes);
  return result;
}
