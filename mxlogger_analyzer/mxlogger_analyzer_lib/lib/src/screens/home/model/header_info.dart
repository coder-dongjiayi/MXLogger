import 'dart:convert';

/// 数据页头部信息：总条数、起止时间、文件名、文件头 map。
class HeaderInfo {
  const HeaderInfo({
    this.total = 0,
    this.minUs,
    this.maxUs,
    this.fileName = "",
    this.header = const {},
  });

  final int total;
  final int? minUs;
  final int? maxUs;
  final String fileName;

  /// 文件头（写入端环境信息）。fileHeader 是 JSON map 时解析展开，
  /// 否则整体作为单字段展示。
  final Map<String, Object?> header;

  static Map<String, Object?> parseHeader(String? raw) {
    final String text = raw?.trim() ?? "";
    if (text.isEmpty) return const {};
    try {
      final Object? value = jsonDecode(text);
      if (value is Map) return value.map((k, v) => MapEntry("$k", v));
    } catch (_) {}
    return {"fileHeader": text};
  }
}
