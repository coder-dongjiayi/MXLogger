import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 搜索关键词高亮（对齐设计稿 mark 样式：hl 35% 底 + markText 文字）。
/// [query] 为空或无命中时返回单一 span。
List<InlineSpan> mxHighlightSpans(
  String text,
  String query, {
  required TextStyle style,
  required MXTokens tokens,
}) {
  if (query.isEmpty) return [TextSpan(text: text, style: style)];
  final String lower = text.toLowerCase();
  final String q = query.toLowerCase();
  if (!lower.contains(q)) return [TextSpan(text: text, style: style)];

  final TextStyle markStyle = style.copyWith(
    color: tokens.markText,
    backgroundColor: tokens.hl.withValues(alpha: 0.35),
  );
  final List<InlineSpan> spans = [];
  int index = 0;
  while (true) {
    final int hit = lower.indexOf(q, index);
    if (hit < 0) {
      spans.add(TextSpan(text: text.substring(index), style: style));
      break;
    }
    if (hit > index) spans.add(TextSpan(text: text.substring(index, hit), style: style));
    spans.add(TextSpan(text: text.substring(hit, hit + q.length), style: markStyle));
    index = hit + q.length;
  }
  return spans;
}
