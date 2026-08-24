import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/json_lines_parser.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

/// 在独立 isolate 中解析日志文件，并通过 SendPort 回传真实进度（0.0-1.0）。
/// .mx 走二进制解密+flatbuffer，其余尝试 JSON-lines；解析失败返回 null。
///
/// .mx 文件足够大时会**按记录边界切段、多 isolate 并行解密**：解密占了导入
/// 耗时的绝大部分（127 MiB 实测 37.5s，同样条数的明文只要 0.7s），而每条记录
/// 是各自独立加密的，切开就能并行。
class ParseIsolate {
  ParseIsolate._();

  /// 单个 worker 至少分到这么多字节才值得并行：spawn 一个 isolate 加上字节
  /// 转移约十几毫秒，小文件切太碎反而更慢
  static const int _minBytesPerWorker = 4 * 1024 * 1024;

  /// worker 上限：再多也吃不满，且每个 worker 都要占一份分段内存
  static const int _maxWorkers = 8;

  /// [cryptPairs] 为多组候选解密参数，按顺序依次尝试（见 [MxBinaryParser.parse]）。
  ///
  /// **[bytes] 的所有权会转移给解析 isolate，调用方在此之后不可再读它。**
  static Future<MxParseResult?> run({
    required Uint8List bytes,
    required bool isMx,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    void Function(double fraction)? onProgress,
  }) async {
    if (isMx) {
      final int workers = _workerCount(bytes.length);
      if (workers > 1) {
        final List<({int start, int end})> ranges =
            MxBinaryParser.splitRanges(bytes, workers);
        if (ranges.length > 1) {
          return _runParallel(
            bytes: bytes,
            ranges: ranges,
            cryptPairs: cryptPairs,
            onProgress: onProgress,
          );
        }
      }
    }
    return _runWhole(
      bytes: bytes,
      isMx: isMx,
      cryptPairs: cryptPairs,
      onProgress: onProgress,
    );
  }

  /// 并行度：受核数、数据量、上限三者共同约束
  static int _workerCount(int byteLength) {
    final int byCores = Platform.numberOfProcessors - 1;
    final int byBytes = byteLength ~/ _minBytesPerWorker;
    return max(1, min(min(byCores, byBytes), _maxWorkers));
  }

  /// 分段并行：各段独立解密，结果按段序拼回，进度按段字节数加权汇总
  static Future<MxParseResult?> _runParallel({
    required Uint8List bytes,
    required List<({int start, int end})> ranges,
    required List<MxCryptPair> cryptPairs,
    void Function(double fraction)? onProgress,
  }) async {
    final int total = ranges.fold(
        0, (int sum, ({int start, int end}) r) => sum + (r.end - r.start));
    final List<double> fractions = List<double>.filled(ranges.length, 0);

    void report(int index, double fraction) {
      fractions[index] = fraction;
      if (onProgress == null || total <= 0) return;
      double done = 0;
      for (int i = 0; i < ranges.length; i++) {
        done = done + fractions[i] * (ranges[i].end - ranges[i].start);
      }
      onProgress(done / total);
    }

    final List<Future<MxParseResult?>> jobs = <Future<MxParseResult?>>[];
    for (int i = 0; i < ranges.length; i++) {
      final ({int start, int end}) range = ranges[i];
      jobs.add(_spawnChunk(
        // sublist 而不是 sublistView：转移所有权要求独占底层内存，
        // 多个 worker 不能共享同一个 buffer 的视图
        chunk: bytes.sublist(range.start, range.end),
        // 文件头按约定是全文件首条记录，只有段 0 可能含它
        allowFileHeader: i == 0,
        cryptPairs: cryptPairs,
        onProgress: (double fraction) => report(i, fraction),
      ));
    }

    final List<MxParseResult?> results = await Future.wait(jobs);
    final List<LogRecord> records = <LogRecord>[];
    String? fileHeader;
    int errorCount = 0;
    for (final MxParseResult? result in results) {
      // 任一段失败即整体失败，与单 isolate 路径的语义一致
      if (result == null) return null;
      records.addAll(result.records);
      fileHeader ??= result.fileHeader;
      errorCount = errorCount + result.errorCount;
    }
    onProgress?.call(1);
    return MxParseResult(
        records: records, fileHeader: fileHeader, errorCount: errorCount);
  }

  static Future<MxParseResult?> _spawnChunk({
    required Uint8List chunk,
    required bool allowFileHeader,
    required List<MxCryptPair> cryptPairs,
    required void Function(double fraction) onProgress,
  }) =>
      _receive(
        (SendPort port) => _ChunkRequest(
          port,
          TransferableTypedData.fromList(<Uint8List>[chunk]),
          allowFileHeader,
          cryptPairs,
        ),
        _chunkEntry,
        onProgress,
      );

  /// 整文件单 isolate：非 .mx，或文件小到不值得切段时走这里
  static Future<MxParseResult?> _runWhole({
    required Uint8List bytes,
    required bool isMx,
    required List<MxCryptPair> cryptPairs,
    void Function(double fraction)? onProgress,
  }) =>
      _receive(
        (SendPort port) => _WholeRequest(
          port,
          TransferableTypedData.fromList(<Uint8List>[bytes]),
          isMx,
          cryptPairs,
        ),
        _wholeEntry,
        onProgress,
      );

  /// spawn 一个 isolate 并消费它的进度/结果消息
  static Future<MxParseResult?> _receive<T>(
    T Function(SendPort port) buildRequest,
    void Function(T request) entry,
    void Function(double fraction)? onProgress,
  ) async {
    final ReceivePort receivePort = ReceivePort();
    try {
      await Isolate.spawn(entry, buildRequest(receivePort.sendPort));
    } catch (_) {
      receivePort.close();
      return null;
    }

    MxParseResult? result;
    await for (final Object? message in receivePort) {
      if (message is double) {
        onProgress?.call(message);
      } else if (message is _ParseResponse) {
        result = message.result;
        break;
      }
    }
    receivePort.close();
    return result;
  }

  /// 进度按 1% 节流，避免端口消息风暴
  static void Function(int, int) _reporter(SendPort port) {
    double lastReported = 0;
    return (int processed, int total) {
      if (total <= 0) return;
      final double fraction = processed / total;
      if (fraction - lastReported >= 0.01 || fraction >= 1) {
        lastReported = fraction;
        port.send(fraction);
      }
    };
  }

  static void _wholeEntry(_WholeRequest request) {
    // 转移过来的内存在此 isolate 落地，不产生额外拷贝
    final Uint8List bytes = request.data.materialize().asUint8List();
    MxParseResult? result;
    try {
      if (request.isMx) {
        result = MxBinaryParser.parse(
          bytes,
          cryptPairs: request.cryptPairs,
          onProgress: _reporter(request.port),
        );
      } else {
        result = JsonLinesParser.parse(utf8.decode(bytes),
            onProgress: _reporter(request.port));
      }
    } catch (_) {
      result = null;
    }
    request.port.send(_ParseResponse(result));
  }

  static void _chunkEntry(_ChunkRequest request) {
    final Uint8List chunk = request.data.materialize().asUint8List();
    MxParseResult? result;
    try {
      result = MxBinaryParser.parseChunk(
        chunk,
        allowFileHeader: request.allowFileHeader,
        cryptPairs: request.cryptPairs,
        onProgress: _reporter(request.port),
      );
    } catch (_) {
      result = null;
    }
    request.port.send(_ParseResponse(result));
  }
}

/// 整文件请求
class _WholeRequest {
  const _WholeRequest(this.port, this.data, this.isMx, this.cryptPairs);

  final SendPort port;

  /// 日志字节，所有权已从调用方转移过来（见 [ParseIsolate.run]）
  final TransferableTypedData data;
  final bool isMx;
  final List<MxCryptPair> cryptPairs;
}

/// 单个分段请求
class _ChunkRequest {
  const _ChunkRequest(
      this.port, this.data, this.allowFileHeader, this.cryptPairs);

  final SendPort port;
  final TransferableTypedData data;

  /// 只有段 0 允许把首条识别为文件头
  final bool allowFileHeader;
  final List<MxCryptPair> cryptPairs;
}

class _ParseResponse {
  const _ParseResponse(this.result);

  final MxParseResult? result;
}
