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

  /// 解密/反序列化失败的条数；被跳过的一段损坏字节也各计一次
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

  /// 一条记录（flatbuffer 根偏移 + vtable + 表）不可能比这更短，重同步时据此过滤
  static const int _minItemSize = 24;

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
    final ByteData byteData = ByteData.sublistView(binaryData);
    final int totalSize = byteData.getUint32(0, Endian.little);
    return _parseFrom(
      binaryData,
      begin: _sizeofUint32,
      limit: min(_sizeofUint32 + totalSize, binaryData.length),
      allowFileHeader: true,
      pairs: _resolvePairs(cryptPairs, cryptKey, iv),
      onProgress: onProgress,
    );
  }

  /// 解析 [splitRanges] 切出的一段。段内是连续的 `[uint32 itemSize][item]`，
  /// 不含文件开头那 4 字节 totalSize，所以从偏移 0 开始走。
  /// [allowFileHeader] 只有段 0 传 true——文件头按约定是全文件首条记录。
  static MxParseResult parseChunk(
    Uint8List chunk, {
    required bool allowFileHeader,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    String? cryptKey,
    String? iv,
    void Function(int processed, int total)? onProgress,
  }) {
    return _parseFrom(
      chunk,
      begin: 0,
      limit: chunk.length,
      allowFileHeader: allowFileHeader,
      pairs: _resolvePairs(cryptPairs, cryptKey, iv),
      onProgress: onProgress,
    );
  }

  /// 按记录边界把有效数据切成至多 [count] 段，供多 isolate 并行解密。
  ///
  /// 每条记录都是用同一 KEY/IV **各自独立**做 CFB 加密的（解密时反馈块每次
  /// 重置为 IV），所以只要不在记录中间切开，各段就能完全独立解密。
  /// 这里只走长度前缀、不解密，127 MiB / 77 万条实测 64ms——相对并行省下的
  /// 近 30 秒可以忽略。
  /// 返回的段两两相接、覆盖全部有效记录；数据不可用时返回空列表。
  static List<({int start, int end})> splitRanges(
      Uint8List binaryData, int count) {
    const List<({int start, int end})> empty = <({int start, int end})>[];
    if (binaryData.length < _sizeofUint32 || count < 1) return empty;

    final ByteData byteData = ByteData.sublistView(binaryData);
    final int totalSize = byteData.getUint32(0, Endian.little);
    final int limit = min(_sizeofUint32 + totalSize, binaryData.length);

    // 记录起点（指向各自的长度前缀）
    final List<int> starts = <int>[];
    int begin = _sizeofUint32;
    while (begin + _sizeofUint32 <= limit) {
      final int itemSize = byteData.getUint32(begin, Endian.little);
      if (itemSize <= 0 ||
          begin + _sizeofUint32 + itemSize > binaryData.length) {
        break;
      }
      starts.add(begin);
      begin = begin + _sizeofUint32 + itemSize;
    }
    if (starts.isEmpty) return empty;

    // 长度链在 limit 之前断掉说明后面有损坏字节，这里不解密无法定位下一条
    // 记录，把剩余部分整个交给末段——parseChunk 会在段内重新同步（见 _resync）
    final int end = begin + _sizeofUint32 <= limit ? limit : begin;
    final int perChunk = ((end - _sizeofUint32) / count).ceil();
    final List<({int start, int end})> ranges = <({int start, int end})>[];
    int chunkStart = starts.first;
    for (int i = 1; i < starts.length; i++) {
      // 段数留一个名额给收尾段，避免最后切出一个空段
      if (ranges.length < count - 1 && starts[i] - chunkStart >= perChunk) {
        ranges.add((start: chunkStart, end: starts[i]));
        chunkStart = starts[i];
      }
    }
    ranges.add((start: chunkStart, end: end));
    return ranges;
  }

  static List<MxCryptPair> _resolvePairs(
      List<MxCryptPair> cryptPairs, String? cryptKey, String? iv) {
    if (cryptPairs.isNotEmpty) return cryptPairs;
    if (cryptKey != null && cryptKey.isNotEmpty) {
      return <MxCryptPair>[MxCryptPair(key: cryptKey, iv: iv ?? "")];
    }
    return const <MxCryptPair>[];
  }

  /// 从 [begin] 解析到 [limit]（不含），进度按该区间内已处理字节回报。
  static MxParseResult _parseFrom(
    Uint8List binaryData, {
    required int begin,
    required int limit,
    required bool allowFileHeader,
    required List<MxCryptPair> pairs,
    void Function(int processed, int total)? onProgress,
  }) {
    final List<AesCrypt> candidates =
        pairs.map(_buildCrypt).toList(growable: false);
    // 多组候选时，解出来「像不像一条日志」是判断有没有解错组的唯一依据；
    // 只有一组时无从选择，保持旧行为不额外过滤
    final bool strict = candidates.length > 1;
    // 上一条命中的组下标：同一文件绝大多数记录用同一组，先试它省掉无谓的解密
    int current = 0;

    final ByteData byteData = ByteData.sublistView(binaryData);
    final int origin = begin;
    final int total = limit - origin;

    final List<LogRecord> records = [];
    String? fileHeader;
    int errorCount = 0;

    /// 逐组尝试解出 [start, start+itemSize) 这一条，都解不开返回 null
    LogRecord? decodeAt(int start, int itemSize) {
      final Uint8List buffer = binaryData.sublist(start, start + itemSize);
      if (candidates.isEmpty) return _decode(buffer);
      final Uint8List padded = _replenishDataByte(buffer);
      for (int i = 0; i < candidates.length; i++) {
        final int index = (current + i) % candidates.length;
        final LogRecord? decoded = _decode(padded, crypt: candidates[index]);
        if (decoded == null || (strict && !_isPlausible(decoded))) continue;
        // 本组命中，下一条优先用它
        current = index;
        return decoded;
      }
      return null;
    }

    // 上一条被接受的记录的长度前缀位置及它是否被当作了文件头：长度链在它
    // 后面断掉时，它自己很可能就是被另一段写入覆盖过的那条（见 _resync）
    int lastAccepted = -1;
    int lastAcceptedEnd = -1;
    bool lastAcceptedIsHeader = false;

    while (begin + _sizeofUint32 <= limit) {
      final int itemSize = byteData.getUint32(begin, Endian.little);
      final int start = begin + _sizeofUint32;
      final bool chainOk = itemSize > 0 && start + itemSize <= binaryData.length;

      final LogRecord? record = chainOk ? decodeAt(start, itemSize) : null;
      if (record != null) {
        lastAcceptedIsHeader =
            record.name == fileHeaderName && allowFileHeader && begin == origin;
        if (lastAcceptedIsHeader) {
          // 首条且 name 为约定值时视为文件头，不计入日志记录
          fileHeader = record.msg;
        } else {
          records.add(record);
        }
        lastAccepted = begin;
        lastAcceptedEnd = start + itemSize;
        begin = start + itemSize;
        onProgress?.call(begin > limit ? total : begin - origin, total);
        continue;
      }

      // 解不开但长度链还连着（下一条前缀落在合理范围）：多半是这条用了未提供的
      // Key/IV，按原语义只计一次失败、继续往后走
      if (chainOk &&
          _prefixLooksSane(byteData, start + itemSize, limit, binaryData.length)) {
        errorCount = errorCount + 1;
        begin = start + itemSize;
        onProgress?.call(begin > limit ? total : begin - origin, total);
        continue;
      }

      // 长度链断了：文件里这一段被改写过（典型场景是两个写入端各自持有偏移、
      // 先后写进同一个文件），往后逐字节找下一条能解出来的记录。搜索从上一条
      // 被接受的记录内部开始——覆盖发生在它中间时，它解出来的内容其实已经是
      // 脏的，新链落在它范围内就把它撤掉
      final int scanFrom =
          (lastAccepted >= 0 ? lastAccepted : begin) + _sizeofUint32 + 1;
      final int next = _resync(binaryData, byteData, scanFrom, limit, decodeAt);
      errorCount = errorCount + 1;
      if (next < 0) break;
      if (lastAccepted >= 0 && next < lastAcceptedEnd) {
        // 新链起点落在上一条记录内部：上一条是被覆盖的残片，撤掉并计一次失败
        if (lastAcceptedIsHeader) {
          fileHeader = null;
        } else {
          records.removeLast();
        }
        errorCount = errorCount + 1;
      }
      lastAccepted = -1;
      begin = next;
      onProgress?.call(begin - origin, total);
    }

    return MxParseResult(
        records: records, fileHeader: fileHeader, errorCount: errorCount);
  }

  /// [offset] 处的长度前缀是否落在合理范围内（只看长度，不解密）。
  /// [offset] 已到或越过 [limit] 说明链正好走完，也算合理。
  static bool _prefixLooksSane(
      ByteData byteData, int offset, int limit, int length) {
    if (offset >= limit) return true;
    if (offset + _sizeofUint32 > limit) return false;
    final int itemSize = byteData.getUint32(offset, Endian.little);
    return _itemSizeSane(itemSize) && offset + _sizeofUint32 + itemSize <= length;
  }

  /// 一条记录的长度是否可信：flatbuffer 长度不会小于 [_minItemSize]，且按 4 对齐
  static bool _itemSizeSane(int itemSize) =>
      itemSize >= _minItemSize && itemSize % 4 == 0;

  /// 从 [from] 起逐字节找下一条完整记录的长度前缀位置，找不到返回 -1。
  ///
  /// 为避免在随机字节里误认：长度前缀必须合理（flatbuffer 长度为 4 的倍数、
  /// 不超出 [limit]），该条要解得出并且像一条日志（见 [_isPlausible]），
  /// 且它的下一条要么恰好收在 [limit]，要么同样解得出来。
  static int _resync(
    Uint8List binaryData,
    ByteData byteData,
    int from,
    int limit,
    LogRecord? Function(int start, int itemSize) decodeAt,
  ) {
    for (int offset = from; offset + _sizeofUint32 + _minItemSize <= limit; offset++) {
      final int itemSize = byteData.getUint32(offset, Endian.little);
      final int start = offset + _sizeofUint32;
      if (!_itemSizeSane(itemSize) || start + itemSize > limit) continue;
      final LogRecord? record = decodeAt(start, itemSize);
      if (record == null || !_isPlausible(record)) continue;

      final int nextOffset = start + itemSize;
      if (nextOffset == limit) return offset;
      if (nextOffset + _sizeofUint32 > limit) continue;
      final int nextSize = byteData.getUint32(nextOffset, Endian.little);
      if (!_itemSizeSane(nextSize) ||
          nextOffset + _sizeofUint32 + nextSize > limit) {
        continue;
      }
      final LogRecord? next = decodeAt(nextOffset + _sizeofUint32, nextSize);
      if (next != null && _isPlausible(next)) return offset;
    }
    return -1;
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
