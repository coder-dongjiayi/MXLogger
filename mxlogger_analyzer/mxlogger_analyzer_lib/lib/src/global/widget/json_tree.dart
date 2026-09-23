import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/highlight_text.dart';

/// JSON 树中参与高亮的文本（对象 key、字符串与数字值）里 [query] 的总命中数，
/// 计数顺序与渲染顺序一致（key 先于其值，子节点按声明顺序），
/// 因此第 n 处命中在树里的位置是确定的，供搜索定位按序号跳转。
int mxJsonMatchCount(Object? value, String query) {
  if (query.isEmpty) return 0;
  if (value is Map) {
    int count = 0;
    value.forEach((Object? key, Object? child) {
      count += mxCountMatches("$key", query) + mxJsonMatchCount(child, query);
    });
    return count;
  }
  if (value is List) {
    int count = 0;
    for (final Object? child in value) {
      count += mxJsonMatchCount(child, query);
    }
    return count;
  }
  if (value is String) return mxCountMatches(value, query);
  if (value is num) return mxCountMatches("$value", query);
  return 0;
}

/// JSON 语法着色树（对齐设计稿 JNode）：
/// 对象/数组节点可折叠，深于 [autoDepth] 的层级默认折叠；
/// 折叠时显示 " … N 项/键 "，点击展开；支持关键词高亮。
/// 整树包在 SelectionArea 内，正文可拖选复制（折叠钮点击不受影响）。
///
/// [activeMatch] 为「当前命中」在全树命中里的序号（见 [mxJsonMatchCount]），
/// 该处以强调色实底显示并挂上 [activeKey]；包含它的折叠节点会自动展开。
class JsonTree extends StatelessWidget {
  const JsonTree({
    super.key,
    required this.value,
    this.autoDepth = 2,
    this.query = "",
    this.activeMatch = -1,
    this.activeKey,
  });

  final Object? value;
  final int autoDepth;
  final String query;
  final int activeMatch;
  final GlobalKey? activeKey;

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
          matchOffset: 0,
          activeMatch: activeMatch,
          activeKey: activeKey,
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
    required this.matchOffset,
    required this.activeMatch,
    required this.activeKey,
    required this.leading,
    required this.trailingComma,
  });

  final Object? value;
  final int depth;
  final int autoDepth;
  final String query;

  /// 本节点值（不含父级传来的 key）之前，全树已累计的命中数
  final int matchOffset;

  /// 当前命中的全树序号（-1 为无）与其定位 key
  final int activeMatch;
  final GlobalKey? activeKey;

  /// 行首前缀（对象子节点的 "key": ）
  final List<InlineSpan> leading;
  final bool trailingComma;

  @override
  State<_JsonNode> createState() => _JsonNodeState();
}

class _JsonNodeState extends State<_JsonNode> {
  // 初始折叠深度之内若包含当前命中，直接以展开态出生，命中不会藏在折叠里
  late bool _closed =
      _isContainer && widget.depth >= widget.autoDepth && !_containsActive;

  bool get _isContainer => widget.value is Map || widget.value is List;

  /// 当前命中是否落在本节点值的子树内
  bool get _containsActive {
    if (widget.activeMatch < widget.matchOffset) return false;
    return widget.activeMatch <
        widget.matchOffset + mxJsonMatchCount(widget.value, widget.query);
  }

  @override
  void didUpdateWidget(_JsonNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 搜索跳到本子树里的命中时自动展开，用户手动折叠过的也一样
    if (_closed &&
        (widget.activeMatch != oldWidget.activeMatch || widget.query != oldWidget.query) &&
        _containsActive) {
      _closed = false;
    }
  }

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

    // 子节点按渲染顺序累计命中序号：对象子节点先算 key 再算值
    final List<Widget> childRows = [];
    int offset = widget.matchOffset;
    if (isList) {
      for (int i = 0; i < listValue.length; i++) {
        childRows.add(_JsonNode(
          value: listValue[i],
          depth: widget.depth + 1,
          autoDepth: widget.autoDepth,
          query: widget.query,
          matchOffset: offset,
          activeMatch: widget.activeMatch,
          activeKey: widget.activeKey,
          leading: const [],
          trailingComma: i < listValue.length - 1,
        ));
        offset += mxJsonMatchCount(listValue[i], widget.query);
      }
    } else {
      final List<String> keys = mapValue.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        final String key = keys[i];
        final int keyMatches = mxCountMatches(key, widget.query);
        final bool keyActive =
            widget.activeMatch >= offset && widget.activeMatch < offset + keyMatches;
        childRows.add(_JsonNode(
          value: mapValue[key],
          depth: widget.depth + 1,
          autoDepth: widget.autoDepth,
          query: widget.query,
          matchOffset: offset + keyMatches,
          activeMatch: widget.activeMatch,
          activeKey: widget.activeKey,
          leading: [
            TextSpan(text: "\"", style: base.copyWith(color: tokens.jsonKey)),
            ...mxHighlightSpans(
              key,
              widget.query,
              style: base.copyWith(color: tokens.jsonKey),
              tokens: tokens,
              activeIndex: keyActive ? widget.activeMatch - offset : -1,
              activeKey: keyActive ? widget.activeKey : null,
            ),
            TextSpan(text: "\"", style: base.copyWith(color: tokens.jsonKey)),
            TextSpan(text: ": ", style: faint),
          ],
          trailingComma: i < keys.length - 1,
        ));
        offset += keyMatches + mxJsonMatchCount(mapValue[key], widget.query);
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
    // 当前命中落在本叶子里时，换算成叶子内的第几处
    final int activeIndex = _containsActive ? widget.activeMatch - widget.matchOffset : -1;
    final GlobalKey? activeKey = activeIndex >= 0 ? widget.activeKey : null;
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
        ...mxHighlightSpans(value, widget.query,
            style: style, tokens: tokens, activeIndex: activeIndex, activeKey: activeKey),
        TextSpan(text: "\"", style: style),
      ];
    }
    if (value is num) {
      return mxHighlightSpans("$value", widget.query,
          style: base.copyWith(color: tokens.jsonNum),
          tokens: tokens,
          activeIndex: activeIndex,
          activeKey: activeKey);
    }
    if (value is bool) {
      return [TextSpan(text: "$value", style: base.copyWith(color: tokens.jsonBool))];
    }
    return [TextSpan(text: "$value", style: base)];
  }
}
