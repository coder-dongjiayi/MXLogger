import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/highlight_text.dart';

/// JSON 语法着色树（对齐设计稿 JNode）：
/// 对象/数组节点可折叠，深于 [autoDepth] 的层级默认折叠；
/// 折叠时显示 " … N 项/键 "，点击展开；支持关键词高亮。
/// 整树包在 SelectionArea 内，正文可拖选复制（折叠钮点击不受影响）。
class JsonTree extends StatelessWidget {
  const JsonTree({super.key, required this.value, this.autoDepth = 2, this.query = ""});

  final Object? value;
  final int autoDepth;
  final String query;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 12.5,
          height: 1.7,
          color: MXTokens.of(context).text,
          fontFamilyFallback: MXTheme.monoFontFallback,
        ),
        child: _JsonNode(
          value: value,
          depth: 0,
          autoDepth: autoDepth,
          query: query,
          leading: const [],
          trailingComma: false,
        ),
      ),
    );
  }
}

class _JsonNode extends StatefulWidget {
  const _JsonNode({
    required this.value,
    required this.depth,
    required this.autoDepth,
    required this.query,
    required this.leading,
    required this.trailingComma,
  });

  final Object? value;
  final int depth;
  final int autoDepth;
  final String query;

  /// 行首前缀（对象子节点的 "key": ）
  final List<InlineSpan> leading;
  final bool trailingComma;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  late bool _closed = _isContainer && widget.depth >= widget.autoDepth;

  bool get _isContainer => widget.value is Map || widget.value is List;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final TextStyle base = DefaultTextStyle.of(context).style;
    final TextStyle faint = base.copyWith(color: tokens.faint);

    if (!_isContainer) {
      return Text.rich(TextSpan(children: [
        ...widget.leading,
        ..._leafSpans(widget.value, base, tokens),
        if (widget.trailingComma) TextSpan(text: ",", style: faint),
      ]));
    }

    final bool isList = widget.value is List;
    final List<Object?> listValue = isList ? (widget.value as List).cast<Object?>() : const [];
    final Map<String, Object?> mapValue =
        isList ? const {} : (widget.value as Map).map((k, v) => MapEntry("$k", v));
    final int count = isList ? listValue.length : mapValue.length;
    final String openBrace = isList ? "[" : "{";
    final String closeBrace = isList ? "]" : "}";

    if (count == 0) {
      return Text.rich(TextSpan(children: [
        ...widget.leading,
        TextSpan(text: "$openBrace$closeBrace", style: faint),
        if (widget.trailingComma) TextSpan(text: ",", style: faint),
      ]));
    }

    final String summary =
        isList ? context.l10n.jsonItems(count) : context.l10n.jsonKeys(count);

    final Widget openRow = Text.rich(TextSpan(children: [
      ...widget.leading,
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: GestureDetector(
          onTap: () => setState(() => _closed = !_closed),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: 14,
              child: Text(
                _closed ? "▸" : "▾",
                textAlign: TextAlign.center,
                style: base.copyWith(fontSize: 10, color: tokens.faint, height: 1),
              ),
            ),
          ),
        ),
      ),
      TextSpan(text: openBrace, style: faint),
      if (_closed) ...[
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => setState(() => _closed = false),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                " … $summary ",
                style: faint.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ),
        ),
        TextSpan(text: closeBrace, style: faint),
        if (widget.trailingComma) TextSpan(text: ",", style: faint),
      ],
    ]));

    if (_closed) return openRow;

    final List<Widget> childRows = [];
    if (isList) {
      for (int i = 0; i < listValue.length; i++) {
        childRows.add(_JsonNode(
          value: listValue[i],
          depth: widget.depth + 1,
          autoDepth: widget.autoDepth,
          query: widget.query,
          leading: const [],
          trailingComma: i < listValue.length - 1,
        ));
      }
    } else {
      final List<String> keys = mapValue.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        final String key = keys[i];
        childRows.add(_JsonNode(
          value: mapValue[key],
          depth: widget.depth + 1,
          autoDepth: widget.autoDepth,
          query: widget.query,
          leading: [
            TextSpan(text: "\"", style: base.copyWith(color: tokens.jsonKey)),
            ...mxHighlightSpans(key, widget.query,
                style: base.copyWith(color: tokens.jsonKey), tokens: tokens),
            TextSpan(text: "\"", style: base.copyWith(color: tokens.jsonKey)),
            TextSpan(text: ": ", style: faint),
          ],
          trailingComma: i < keys.length - 1,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        openRow,
        Container(
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: tokens.panel2)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: childRows),
        ),
        Text.rich(TextSpan(children: [
          TextSpan(text: closeBrace, style: faint),
          if (widget.trailingComma) TextSpan(text: ",", style: faint),
        ])),
      ],
    );
  }

  /// 标量叶子：字符串绿/数字橙(支持高亮)、布尔粉、null 斜体灰。
  List<InlineSpan> _leafSpans(Object? value, TextStyle base, MXTokens tokens) {
    if (value == null) {
      return [
        TextSpan(
          text: "null",
          style: base.copyWith(color: tokens.faint, fontStyle: FontStyle.italic),
        ),
      ];
    }
    if (value is String) {
      final TextStyle style = base.copyWith(color: tokens.jsonStr);
      return [
        TextSpan(text: "\"", style: style),
        ...mxHighlightSpans(value, widget.query, style: style, tokens: tokens),
        TextSpan(text: "\"", style: style),
      ];
    }
    if (value is num) {
      return mxHighlightSpans("$value", widget.query,
          style: base.copyWith(color: tokens.jsonNum), tokens: tokens);
    }
    if (value is bool) {
      return [TextSpan(text: "$value", style: base.copyWith(color: tokens.jsonBool))];
    }
    return [TextSpan(text: "$value", style: base)];
  }
}
