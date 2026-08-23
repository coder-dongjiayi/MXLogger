import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/json_lines_parser.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

/// 在独立 isolate 中解析日志文件，并通过 SendPort 回传真实进度（0.0-1.0）。
/// .mx 走二进制解密+flatbuffer，其余尝试 JSON-lines；解析失败返回 null。
class ParseIsolate {
  ParseIsolate._();

  /// [cryptPairs] 为多组候选解密参数，按顺序依次尝试（见 [MxBinaryParser.parse]）。
  static Future<MxParseResult?> run({
    required Uint8List bytes,
    required bool isMx,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    void Function(double fraction)? onProgress,
  }) async {
    final ReceivePort receivePort = ReceivePort();
    try {
      await Isolate.spawn(
        _entry,
        _ParseRequest(receivePort.sendPort, bytes, isMx, cryptPairs),
      );
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

  static void _entry(_ParseRequest request) {
    double lastReported = 0;
    // 进度按 1% 节流，避免端口消息风暴
    void report(int processed, int total) {
      if (total <= 0) return;
      final double fraction = processed / total;
      if (fraction - lastReported >= 0.01 || fraction >= 1) {
        lastReported = fraction;
        request.port.send(fraction);
      }
    }

    MxParseResult? result;
    try {
      if (request.isMx) {
        result = MxBinaryParser.parse(
          request.bytes,
          cryptPairs: request.cryptPairs,
          onProgress: report,
        );
      } else {
        result = JsonLinesParser.parse(utf8.decode(request.bytes), onProgress: report);
      }
    } catch (_) {
      result = null;
    }
    request.port.send(_ParseResponse(result));
  }
}

class _ParseRequest {
  const _ParseRequest(this.port, this.bytes, this.isMx, this.cryptPairs);

  final SendPort port;
  final Uint8List bytes;
  final bool isMx;
  final List<MxCryptPair> cryptPairs;
}

class _ParseResponse {
  const _ParseResponse(this.result);

  final MxParseResult? result;
}
