import 'dart:convert';

import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

/// JSON Lines 文本日志解析（对齐设计稿 parseLogFile）：
/// 首行若为不含 ts/level 的对象则视为 header map，后续每行一条日志
/// `{ts, level, name, tags, content}`；任一行不合法则整体判定失败返回 null。
/// [onProgress] 按已处理行数回报真实进度。
class JsonLinesParser {
  JsonLinesParser._();

  static MxParseResult? parse(
    String text, {
    void Function(int processed, int total)? onProgress,
  }) {
    try {
      final List<String> lines = text
          .split("\n")
          .map((String line) => line.trim())
          .where((String line) => line.isNotEmpty)
          .toList();
      if (lines.isEmpty) return null;

      String? headerJson;
      int start = 0;
      final Object? first = jsonDecode(lines.first);
      if (first is Map && !first.containsKey("ts") && !first.containsKey("level")) {
        headerJson = jsonEncode(first);
        start = 1;
      }

      final List<LogRecord> records = [];
      for (int i = start; i < lines.length; i++) {
        final Object? item = jsonDecode(lines[i]);
        if (item is! Map) return null;
        final Object? ts = item["ts"];
        final Object? level = item["level"];
        if (ts == null || level == null) return null;

        final int tsMs = ts is num ? ts.toInt() : DateTime.parse("$ts").millisecondsSinceEpoch;
        final Object? content = item["content"];
        final Object? tags = item["tags"];
        records.add(LogRecord(
          name: "${item["name"] ?? "-"}",
          tag: tags is List ? tags.join(" ") : "",
          msg: content is String ? content : jsonEncode(content ?? ""),
          level: _levelOf("$level"),
          threadId: 0,
          isMainThread: 0,
          timestamp: tsMs * 1000,
        ));
        onProgress?.call(i + 1, lines.length);
      }
      if (records.isEmpty) return null;
      return MxParseResult(records: records, fileHeader: headerJson);
    } catch (_) {
      return null;
    }
  }

  static int _levelOf(String level) {
    switch (level.toLowerCase()) {
      case "debug":
        return 0;
      case "info":
        return 1;
      case "warn":
      case "warning":
        return 2;
      case "error":
        return 3;
      case "fatal":
        return 4;
      default:
        return 0;
    }
  }
}
