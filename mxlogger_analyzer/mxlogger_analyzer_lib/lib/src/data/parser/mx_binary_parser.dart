import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';

/// 解析出的单条日志记录（纯数据，可跨 isolate 传输）。
class LogRecord {
  const LogRecord({
    required this.name,
    required this.tag,
    required this.msg,
    required this.level,
    required this.threadId,
    required this.isMainThread,
    required this.timestamp,
  });

  final String name;
  final String tag;
  final String msg;
  final int level;
  final int threadId;
  final int isMainThread;

  /// 微秒时间戳（native 端 gettimeofday 精度）
  final int timestamp;
}

/// 单个 .mx 文件的解析结果。
class MxParseResult {
  const MxParseResult({
    required this.records,
    this.fileHeader,
    this.errorCount = 0,
  });

  final List<LogRecord> records;

  /// 文件首条 name 为 [MxBinaryParser.fileHeaderName] 的记录，msg 即写入端环境信息
  final String? fileHeader;

  /// 解密/反序列化失败的条数
  final int errorCount;
}

/// 一组解密参数（KEY / IV）。可跨 isolate 传输。
class MxCryptPair {
  const MxCryptPair({required this.key, this.iv = ""});

  final String key;

  /// 为空时与 native 端约定回退为 key
  final String iv;

  @override
  bool operator ==(Object other) =>
      other is MxCryptPair && other.key == key && other.iv == iv;

  @override
  int get hashCode => Object.hash(key, iv);
}

/// MXLogger .mx 二进制解析器。
///
/// 文件布局（小端）：
/// `[uint32 totalSize][uint32 itemSize][item bytes]...`，
/// item 为 flatbuffer 序列化的 [LogSerialize]，可选 AES-CFB(128) 加密。
class MxBinaryParser {
  MxBinaryParser._();

  static const String fileHeaderName = "com.djy.mxlogger.fileHeader";
  static const int _sizeofUint32 = 4;
  static const int _aesBlockLength = 16;

  /// 纯 CPU 计算，无平台依赖，可放进 isolate 执行。
  ///
  /// [cryptPairs] 为多组候选解密参数，**逐条**按顺序尝试：第一组解不开就换下一组，
  /// 都解不开才计入 errorCount。逐条而非整文件挑一组，是因为同一个文件里的记录
  /// 可能是不同 Key/IV 加密的（写入端中途换过密钥，日志仍追加在同一文件里）。
  /// [cryptKey] / [iv] 是单组的简写入口，仅在 [cryptPairs] 为空时生效；
  /// 两者都为空表示日志未加密。
  /// [onProgress] 按已处理字节数回报真实进度（processed/total）。
  static MxParseResult parse(
    Uint8List binaryData, {
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    String? cryptKey,
    String? iv,
    void Function(int processed, int total)? onProgress,
  }) {
    if (binaryData.length < _sizeofUint32) {
      return const MxParseResult(records: []);
    }

    final List<MxCryptPair> pairs = cryptPairs.isNotEmpty
        ? cryptPairs
        : (cryptKey != null && cryptKey.isNotEmpty)
            ? [MxCryptPair(key: cryptKey, iv: iv ?? "")]
            : const <MxCryptPair>[];
    final List<AesCrypt> candidates =
        pairs.map(_buildCrypt).toList(growable: false);
    // 多组候选时，解出来「像不像一条日志」是判断有没有解错组的唯一依据；
    // 只有一组时无从选择，保持旧行为不额外过滤
    final bool strict = candidates.length > 1;
    // 上一条命中的组下标：同一文件绝大多数记录用同一组，先试它省掉无谓的解密
    int current = 0;

    final ByteData byteData = ByteData.sublistView(binaryData);
    final int totalSize = byteData.getUint32(0, Endian.little);

    final List<LogRecord> records = [];
    String? fileHeader;
    int errorCount = 0;

    int begin = _sizeofUint32;
    while (begin <= totalSize && begin + _sizeofUint32 <= binaryData.length) {
      final int itemSize = byteData.getUint32(begin, Endian.little);
      final int start = begin + _sizeofUint32;
      if (itemSize <= 0 || start + itemSize > binaryData.length) break;

      final Uint8List buffer = binaryData.sublist(start, start + itemSize);
      LogRecord? record;
      if (candidates.isEmpty) {
        record = _decode(buffer);
      } else {
        final Uint8List padded = _replenishDataByte(buffer);
        for (int i = 0; i < candidates.length; i++) {
          final int index = (current + i) % candidates.length;
          final LogRecord? decoded = _decode(padded, crypt: candidates[index]);
          if (decoded == null || (strict && !_isPlausible(decoded))) continue;
          record = decoded;
          // 本组命中，下一条优先用它
          current = index;
          break;
        }
      }

      if (record == null) {
        errorCount = errorCount + 1;
      } else if (record.name == fileHeaderName && begin == _sizeofUint32) {
        // 首条且 name 为约定值时视为文件头，不计入日志记录
        fileHeader = record.msg;
      } else {
        records.add(record);
      }

      begin = begin + _sizeofUint32 + itemSize;
      onProgress?.call(begin > totalSize ? totalSize : begin, totalSize);
    }

    return MxParseResult(records: records, fileHeader: fileHeader, errorCount: errorCount);
  }

  static AesCrypt _buildCrypt(MxCryptPair pair) {
    final AesCrypt crypt = AesCrypt();
    final String ivSource = pair.iv.isEmpty ? pair.key : pair.iv;
    crypt.aesSetKeys(_replenishByte(pair.key), _replenishByte(ivSource));
    crypt.aesSetMode(AesMode.cfb);
    return crypt;
  }

  /// 解密（[crypt] 为空即明文）并还原一条记录，字节解不开时返回 null。
  /// flatbuffer 的字段是惰性读取的，取值必须一并放在这里的 try 内——
  /// 漏到外面会让整个文件的解析被判为失败。
  static LogRecord? _decode(Uint8List bytes, {AesCrypt? crypt}) {
    try {
      final LogSerialize serialize =
          LogSerialize(crypt == null ? bytes : crypt.aesDecrypt(bytes));
      return LogRecord(
        name: serialize.name,
        tag: serialize.tag,
        msg: serialize.msg,
        level: serialize.level,
        threadId: serialize.threadId,
        isMainThread: serialize.isMainThread,
        timestamp: serialize.timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  /// 解出来的内容像不像一条真日志：错误的 Key 解出的是随机字节，
  /// flatbuffer 读取几乎必然抛错，极小概率不抛错时再用「时间戳非 0」兜一层。
  static bool _isPlausible(LogRecord record) =>
      record.timestamp > 0 || record.name == fileHeaderName;

  /// key / iv 不足 16 字节时补 0x00，超出截断（与写入端对齐）
  static Uint8List _replenishByte(String input) {
    final Uint8List bytes = Uint8List.fromList(utf8.encode(input));
    if (bytes.length == _aesBlockLength) return bytes;
    final Uint8List result = Uint8List(_aesBlockLength);
    final int number = min(_aesBlockLength, bytes.length);
    for (int i = 0; i < number; i++) {
      result[i] = bytes[i];
    }
    return result;
  }

  /// 密文长度补齐到 16 的整数倍（CFB 按块解密）
  static Uint8List _replenishDataByte(Uint8List buffer) {
    final int bufferLen = buffer.length;
    if (bufferLen % _aesBlockLength == 0) return buffer;
    final int blockCount = (bufferLen / _aesBlockLength).ceil();
    final Uint8List result = Uint8List(blockCount * _aesBlockLength);
    result.setRange(0, bufferLen, buffer);
    return result;
  }
}
