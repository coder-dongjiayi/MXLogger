import 'dart:convert';

/// 时间四段式（对齐设计稿 fmtTs）：date / time / ms / full。
typedef MxTimeParts = ({String date, String time, String ms, String full});

/// 文件大小自动选择单位，最多保留一位小数。
String mxFmtBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes < 0 ? 0 : bytes.toDouble();
  int unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  // 舍入后达到下一单位时继续换算，避免显示 1024 KB。
  if (unit > 0 && size >= 1023.95 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  final text = size.toStringAsFixed(unit == 0 ? 0 : 1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} ${units[unit]}';
}

MxTimeParts mxFmtTs(DateTime dt) {
  String pad(int n, [int w = 2]) => n.toString().padLeft(w, "0");
  final String date = "${dt.year}-${pad(dt.month)}-${pad(dt.day)}";
  final String time = "${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}";
  final String ms = pad(dt.millisecond, 3);
  return (date: date, time: time, ms: ms, full: "$date $time.$ms");
}

/// 紧凑计数（对齐设计稿 fmtCount）：1234→1.2k，58210→5.8w，精确值放 tooltip。
String mxFmtCount(int n) {
  if (n < 1000) return "$n";
  if (n < 10000) {
    final String s = (n / 1000).toStringAsFixed(n < 9950 ? 1 : 0);
    return "${s.endsWith(".0") ? s.substring(0, s.length - 2) : s}k";
  }
  final String s = (n / 10000).toStringAsFixed(n < 99500 ? 1 : 0);
  return "${s.endsWith(".0") ? s.substring(0, s.length - 2) : s}w";
}

/// 内容是 JSON 对象/数组时返回解码结果，否则 null。
Object? mxTryParseJson(String? source) {
  final String trimmed = source?.trim() ?? "";
  if (!(trimmed.startsWith("{") || trimmed.startsWith("["))) return null;
  try {
    final Object? value = jsonDecode(trimmed);
    return (value is Map || value is List) ? value : null;
  } catch (_) {
    return null;
  }
}

/// 折叠时的缩略（对齐设计稿 previewOf）：JSON 压成单行，文本取首行，160 字符截断。
String mxPreviewOf(String? content) {
  final String raw = content ?? "";
  final Object? json = mxTryParseJson(raw);
  final String line = json != null ? jsonEncode(json) : raw.split("\n").first;
  return line.length > 160 ? "${line.substring(0, 160)}…" : line;
}

/// 正文总行数（JSON 按两空格缩进格式化后计），用于「查看完整」提示。
int mxLineCountOf(String? content) {
  final String raw = content ?? "";
  final Object? json = mxTryParseJson(raw);
  final String text =
      json != null ? const JsonEncoder.withIndent("  ").convert(json) : raw;
  return "\n".allMatches(text).length + 1;
}
