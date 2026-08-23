import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';

/// 工具栏（对齐设计稿）：搜索框（内嵌范围切换）+ 时间范围 + 折叠全部。
class DataToolbar extends MXConsumerStatefulWidget {
  const DataToolbar({super.key});

  @override
  DataToolbarState createState() => DataToolbarState();
}

class DataToolbarState extends MXConsumerState<DataToolbar> {
  final TextEditingController _searchController = TextEditingController();
  // onKeyEvent 拦截上下键/回车/Esc（须先于 TextField 默认光标移动处理）
  late final FocusNode _searchFocusNode = FocusNode(onKeyEvent: _handleSearchKey);
  Timer? _debounce;
  bool _searchFocused = false;

  // 联想浮层：# 选 tag / @ 选 name
  final LayerLink _fieldLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  // 给输入框固定身份：chip 出现/消失导致布局分支切换时元素随之迁移而非重建，
  // 从而保留焦点（选中 chip 后仍可继续输入）
  final GlobalKey _textFieldKey = GlobalKey();
  OverlayEntry? _suggestOverlay;

  /// 当前联想类型："#" / "@" / ""（非联想模式）
  String _suggestKind = "";

  /// 当前类型的全部候选（进入该类型时拉取一次并缓存）
  List<String> _allTags = const [];
  List<String> _allNames = const [];

  /// 按输入过滤后的候选
  List<String> _suggestions = const [];

  /// 上下键高亮的候选下标
  int _highlight = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 输入变化：`#`/`@` 开头进入联想模式（不作普通关键词过滤），
  /// 其余走 180ms 防抖后应用关键词（对齐设计稿 onQuery）。
  void _onQueryChanged(String value) {
    final String kind = value.startsWith("#")
        ? "#"
        : value.startsWith("@")
            ? "@"
            : "";

    if (kind.isEmpty) {
      _closeSuggest();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), () {
        if (!mounted) return;
        store.filter
            .update((LogFilterState state) => state.copyWith(keyword: value.trim()));
      });
      return;
    }

    _debounce?.cancel();
    _openSuggest(kind, value.substring(1).trim());
  }

  /// 进入/刷新联想：切换类型时拉取全部候选并缓存，再按输入过滤刷新浮层
  Future<void> _openSuggest(String kind, String query) async {
    if (_suggestKind != kind) {
      _suggestKind = kind;
      final List<String> options =
          await (kind == "#" ? store.tagOptions : store.nameOptions).future;
      if (!mounted || _suggestKind != kind) return;
      if (kind == "#") {
        _allTags = options;
      } else {
        _allNames = options;
      }
    }
    _suggestions = _filterOptions(kind, query);
    _highlight = 0;
    _showOverlay();
  }

  List<String> _filterOptions(String kind, String query) {
    final List<String> all = kind == "#" ? _allTags : _allNames;
    if (query.isEmpty) return all;
    final String lower = query.toLowerCase();
    return all.where((String e) => e.toLowerCase().contains(lower)).toList();
  }

  /// 退格删 chip（输入框为空时）/ 上下键导航 / 回车选中 / Esc 关闭
  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;

    // 输入框为空时按退格删除最后一个 chip（name 在 tag 之后，先删 name）
    if (key == LogicalKeyboardKey.backspace && _searchController.text.isEmpty) {
      final LogFilterState filter = store.filter.value;
      if (filter.names.isNotEmpty) {
        _removeName(filter.names.last);
        return KeyEventResult.handled;
      }
      if (filter.tags.isNotEmpty) {
        _removeTag(filter.tags.last);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 以下为联想浮层打开时的键盘操作
    if (_suggestOverlay == null) return KeyEventResult.ignored;
    final int count = _suggestions.length;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (count > 0) _moveHighlight((_highlight + 1) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (count > 0) _moveHighlight((_highlight - 1 + count) % count);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (count > 0 && _highlight < count) {
        _selectSuggestion(_suggestKind, _suggestions[_highlight]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _closeSuggest();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int index) {
    _highlight = index;
    _suggestOverlay?.markNeedsBuild();
  }

  /// 选中一个 tag/name：追加到多选过滤（去重），清空输入以便继续选下一个
  void _selectSuggestion(String kind, String value) {
    _closeSuggest();
    _searchController.clear();
    store.filter.update(
      (LogFilterState state) =>
          kind == "#" ? state.addTag(value) : state.addName(value),
    );
    // 布局重建后保持输入框聚焦，便于连续选择
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _removeTag(String tag) =>
      store.filter.update((LogFilterState state) => state.removeTag(tag));

  void _removeName(String name) =>
      store.filter.update((LogFilterState state) => state.removeName(name));

  /// 退出联想模式（复位类型 + 移除浮层）
  void _closeSuggest() {
    _suggestKind = "";
    _suggestions = const [];
    _highlight = 0;
    _removeOverlay();
  }

  void _showOverlay() {
    if (_suggestOverlay == null) {
      _suggestOverlay = OverlayEntry(builder: _buildSuggestOverlay);
      Overlay.of(context).insert(_suggestOverlay!);
    } else {
      _suggestOverlay!.markNeedsBuild();
    }
  }

  void _removeOverlay() {
    _suggestOverlay?.remove();
    _suggestOverlay = null;
  }

  Widget _buildSuggestOverlay(BuildContext _) {
    final MXTokens tokens = MXTokens.of(context);
    final RenderBox? box =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final double width = box?.size.width ?? 320;
    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _fieldLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.bottomLeft,
        followerAnchor: Alignment.topLeft,
        offset: const Offset(0, 6),
        // 归入搜索框的 TapRegion：点击浮层不触发 TextField 失焦，
        // 否则失焦回调会先移除浮层导致点击项的 onTap 落空
        child: TextFieldTapRegion(
          child: _SuggestList(
            tokens: tokens,
            header: _suggestKind == "#"
                ? context.l10n.searchPickTag
                : context.l10n.searchPickName,
            prefix: _suggestKind,
            items: _suggestions,
            highlight: _highlight,
            onPick: (String value) => _selectSuggestion(_suggestKind, value),
          ),
        ),
      ),
    );
  }

  /// × 一键清除搜索内容（立即生效，不走防抖）
  void _clearSearch() {
    _debounce?.cancel();
    _closeSuggest();
    _searchController.clear();
    store.filter.update((LogFilterState state) => state.copyWith(keyword: ""));
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final LogFilterState filter = ref.watch(store.filter);
    final bool timeOpen = ref.watch(store.timeOpen);
    final bool allCollapsed = ref.watch(store.allCollapsed);

    // 过滤条件被整体清空（如点「全部清除」）时同步清空输入框
    if (filter.keyword.isEmpty && _searchController.text.isNotEmpty && !_searchFocused) {
      _searchController.clear();
    }

    final bool mobile = context.isMobileLayout;
    final Widget timeButton = _ToolButton(
      icon: Icons.access_time,
      label: context.l10n.timeRange,
      // 移动端只留图标（设计稿 hide-mobile），文案会把搜索框挤到不可用
      showLabel: !mobile,
      active: timeOpen || filter.timeActive,
      badge: filter.timeActive ? "1" : null,
      onTap: () => store.timeOpen.value = !timeOpen,
    );
    // 时间排序切换：默认正序（旧→新），点一下按时间倒序重排，再点切回
    final Widget sortButton = _ToolButton(
      icon: filter.ascending ? Icons.arrow_downward : Icons.arrow_upward,
      label: filter.ascending ? context.l10n.sortAsc : context.l10n.sortDesc,
      showLabel: !mobile,
      active: !filter.ascending,
      onTap: () => store.filter.update(
          (LogFilterState state) => state.copyWith(ascending: !state.ascending)),
    );
    final Widget foldButton = _ToolButton(
      icon: Icons.menu,
      label: allCollapsed ? context.l10n.unfoldAll : context.l10n.foldAll,
      showLabel: !mobile,
      active: allCollapsed,
      onTap: _toggleFoldAll,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.mxPadX, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      // 移动端搜索框独占一行（设计稿 search min-width:100%），按钮落到下一行
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchField(tokens, filter),
                const SizedBox(height: 8),
                Row(
                  children: [
                    timeButton,
                    const SizedBox(width: 10),
                    sortButton,
                    const SizedBox(width: 10),
                    foldButton,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520, minWidth: 220),
                    child: _searchField(tokens, filter),
                  ),
                ),
                const SizedBox(width: 10),
                timeButton,
                const SizedBox(width: 10),
                sortButton,
                const SizedBox(width: 10),
                foldButton,
              ],
            ),
    );
  }

  /// 折叠全部/展开全部：切默认折叠态并清掉单条翻转，
  /// 后续分页加载的日志也自动跟随（无需逐条登记 id）
  void _toggleFoldAll() {
    store.allCollapsed.value = !store.allCollapsed.value;
    store.foldToggled.value = const <int>{};
  }

  Widget _searchField(MXTokens tokens, LogFilterState filter) {
    final bool hasChips = filter.tags.isNotEmpty || filter.names.isNotEmpty;
    return Focus(
      onFocusChange: (bool value) {
        setState(() => _searchFocused = value);
        // 失焦关闭联想浮层（点击浮层项不改变输入框焦点，不会误关）
        if (!value) _closeSuggest();
      },
      child: CompositedTransformTarget(
        link: _fieldLink,
        child: Container(
          key: _fieldKey,
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _searchFocused ? tokens.accent : tokens.border),
          ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Icon(Icons.search, size: 14, color: tokens.muted.withValues(alpha: 0.55)),
            ),
            Expanded(
              // 已选 tag/name 以 chip 形式显示在框内，多则换行；文本框跟随其后
              child: hasChips
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final String tag in filter.tags)
                            _InBoxChip(
                              prefix: "#",
                              label: tag,
                              color: tokens.tagText,
                              onRemove: () => _removeTag(tag),
                            ),
                          for (final String name in filter.names)
                            _InBoxChip(
                              prefix: "@",
                              label: name,
                              color: tokens.nameText,
                              onRemove: () => _removeName(name),
                            ),
                          // 有 chip 时输入框受限较窄，用短提示避免文案被截断
                          SizedBox(
                            width: 150,
                            child: _textField(tokens, hint: context.l10n.searchLogsHintShort),
                          ),
                        ],
                      ),
                    )
                  : _textField(tokens, hint: context.l10n.searchLogsHint),
            ),
            // 有搜索内容时显示 ×，一键清除
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (BuildContext context, TextEditingValue value, Widget? child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return _ClearSearchButton(onTap: _clearSearch);
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
        ),
      ),
    );
  }

  Widget _textField(MXTokens tokens, {required String hint}) {
    final double fontSize = context.mxInputFontSize(13.5);
    return TextField(
      key: _textFieldKey,
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: _onQueryChanged,
      style: TextStyle(fontSize: fontSize, color: tokens.text),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(fontSize: fontSize, color: tokens.faint.withValues(alpha: 0.7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      ),
    );
  }
}

/// 搜索框内已选 tag/name 小胶囊（前缀 # / @，可点 × 移除）。
class _InBoxChip extends StatelessWidget {
  const _InBoxChip({
    required this.prefix,
    required this.label,
    required this.color,
    required this.onRemove,
  });

  final String prefix;
  final String label;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.only(left: 8, right: 3, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              "$prefix$label",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontFamilyFallback: MXTheme.monoFontFallback,
              ),
            ),
          ),
          const SizedBox(width: 2),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(Icons.close, size: 13, color: color.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索联想浮层：# 选 tag / @ 选 name，随输入过滤，上下键/回车或点击选中。
class _SuggestList extends StatelessWidget {
  const _SuggestList({
    required this.tokens,
    required this.header,
    required this.prefix,
    required this.items,
    required this.highlight,
    required this.onPick,
  });

  final MXTokens tokens;
  final String header;

  /// "#" 或 "@"，作为每项前缀色标
  final String prefix;
  final List<String> items;

  /// 上下键高亮的下标
  final int highlight;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.panel,
      elevation: 8,
      borderRadius: BorderRadius.circular(10),
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.border),
        ),
        constraints: const BoxConstraints(maxHeight: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
              child: Text(
                header,
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.faint,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Divider(height: 1, color: tokens.border),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    context.l10n.searchNoMatch,
                    style: TextStyle(fontSize: 12.5, color: tokens.faint),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _SuggestItem(
                      tokens: tokens,
                      prefix: prefix,
                      label: items[index],
                      highlighted: index == highlight,
                      onTap: () => onPick(items[index]),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 联想浮层单项：hover / 上下键高亮，前缀 # / @ 用对应徽标色。
class _SuggestItem extends StatefulWidget {
  const _SuggestItem({
    required this.tokens,
    required this.prefix,
    required this.label,
    required this.highlighted,
    required this.onTap,
  });

  final MXTokens tokens;
  final String prefix;
  final String label;

  /// 键盘导航当前选中
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_SuggestItem> createState() => _SuggestItemState();
}

class _SuggestItemState extends State<_SuggestItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = widget.tokens;
    final Color prefixColor = widget.prefix == "#" ? tokens.tagText : tokens.nameText;
    final bool active = _hovering || widget.highlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: active ? tokens.panel2 : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Text(
                widget.prefix,
                style: TextStyle(
                  fontSize: 12.5,
                  color: prefixColor.withValues(alpha: 0.7),
                  fontFamilyFallback: MXTheme.monoFontFallback,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: active ? tokens.text : tokens.muted,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索框尾部 × 清除按钮（有搜索内容时出现）。
class _ClearSearchButton extends StatefulWidget {
  const _ClearSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ClearSearchButton> createState() => _ClearSearchButtonState();
}

class _ClearSearchButtonState extends State<_ClearSearchButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Tooltip(
      message: context.l10n.clearSearchTip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _hovering ? tokens.border : tokens.panel2,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.close,
              size: 12,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 工具栏描边按钮（时间范围 / 折叠全部），active 时强调色。
class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showLabel = true,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// 移动端隐藏文案只留图标（label 仍作为 tooltip）
  final bool showLabel;
  final String? badge;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color fg = widget.active ? tokens.accent : tokens.muted;
    final Color borderColor = widget.active
        ? tokens.accent
        : (_hovering ? tokens.faint : tokens.border);
    return Tooltip(
      message: widget.showLabel ? "" : widget.label,
      child: MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // 无文案时左右收窄成方形图标钮，上下加高到可点尺寸
          padding: widget.showLabel
              ? const EdgeInsets.symmetric(horizontal: 13, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: widget.showLabel ? 13 : 15, color: fg),
              if (widget.showLabel) ...[
                const SizedBox(width: 6),
                Text(widget.label, style: TextStyle(fontSize: 12.5, color: fg)),
              ],
              if (widget.badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.badge ?? "",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: tokens.onAccent,
                      fontFamilyFallback: MXTheme.monoFontFallback,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
