import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 搜索关键词高亮（对齐设计稿 mark 样式：hl 35% 底 + markText 文字）。
/// [query] 为空或无命中时返回单一 span。
///
/// [activeIndex] 指定本段文本里第几处命中（从 0 起）为「当前命中」：改用强调色实底反色字，
/// 并在它前面插入一个零尺寸的 [WidgetSpan] 挂上 [activeKey]，调用方凭这个 key
/// 用 `Scrollable.ensureVisible` 把它滚到可视区（全屏详情搜索定位用）。
List<InlineSpan> mxHighlightSpans(
  String text,
  String query, {
  required TextStyle style,
  required MXTokens tokens,
  int activeIndex = -1,
  GlobalKey? activeKey,
}) {
  if (query.isEmpty) return [TextSpan(text: text, style: style)];
  final String lower = text.toLowerCase();
  final String q = query.toLowerCase();
  if (!lower.contains(q)) return [TextSpan(text: text, style: style)];

  final TextStyle markStyle = style.copyWith(
    color: tokens.markText,
    backgroundColor: tokens.hl.withValues(alpha: 0.35),
  );
  final TextStyle activeStyle = style.copyWith(
    color: tokens.onAccent,
    backgroundColor: tokens.accent,
    fontWeight: FontWeight.w600,
  );
  final List<InlineSpan> spans = [];
  int index = 0;
  int occurrence = 0;
  while (true) {
    final int hit = lower.indexOf(q, index);
    if (hit < 0) {
      spans.add(TextSpan(text: text.substring(index), style: style));
      break;
    }
    if (hit > index) spans.add(TextSpan(text: text.substring(index, hit), style: style));
    final String matched = text.substring(hit, hit + q.length);
    if (occurrence == activeIndex) {
      if (activeKey != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox.shrink(key: activeKey),
        ));
      }
      spans.add(TextSpan(text: matched, style: activeStyle));
    } else {
      spans.add(TextSpan(text: matched, style: markStyle));
    }
    occurrence++;
    index = hit + q.length;
  }
  return spans;
}

/// [text] 中 [query] 的命中次数（忽略大小写，不重叠），与 [mxHighlightSpans] 的切分一致。
int mxCountMatches(String text, String query) {
  if (query.isEmpty || text.isEmpty) return 0;
  final String lower = text.toLowerCase();
  final String q = query.toLowerCase();
  int count = 0;
  int index = lower.indexOf(q);
  while (index >= 0) {
    count++;
    index = lower.indexOf(q, index + q.length);
  }
  return count;
}
