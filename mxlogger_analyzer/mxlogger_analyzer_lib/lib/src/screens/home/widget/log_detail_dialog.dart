import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_share.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/highlight_text.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/json_tree.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/level_badge.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';

/// 全屏查看单条日志（对齐设计稿 modal）：等级色顶边 + 字段表 + 正文内搜索 + 完整正文。
/// Esc / 点击遮罩关闭。
///
/// 正文内搜索：输入即高亮全部命中并显示「第 N / 共 M 处」，回车 / ↓ 下一处、
/// Shift+回车 / ↑ 上一处，自动滚动到当前命中；JSON 里命中藏在折叠节点内时自动展开。
/// 超长日志（几千行的堆栈、几百 KB 的 JSON）靠肉眼很难定位，这是全屏弹窗的主要用途。
Future<void> showLogDetailDialog(BuildContext context, {required LogModel log}) {
  final MXTokens tokens = MXTokens.of(context);
  // Dialog 内部会清掉 MediaQuery padding，安全区在弹出前从宿主 context 取
  final EdgeInsets safeInsets = MediaQuery.viewPaddingOf(context);
  return showDialog<void>(
    context: context,
    barrierColor: tokens.mask,
    // 必须用就近 Navigator：嵌入模式下 MXScope / 主题 / l10n 都在弹窗内的
    // 嵌套 MaterialApp 里，走宿主 root navigator 会脱离分析器组件树
    useRootNavigator: false,
    // 移动端弹窗铺满整屏（底色盖到刘海下），安全区由弹窗内部留白避让
    useSafeArea: !context.isMobileLayout,
    builder: (BuildContext context) =>
        _LogDetailDialog(log: log, safeInsets: safeInsets),
  );
}

class _LogDetailDialog extends StatefulWidget {
  const _LogDetailDialog({required this.log, required this.safeInsets});

  final LogModel log;

  /// 宿主屏幕安全区（移动端弹窗铺满时用于避让状态栏 / home indicator）
  final EdgeInsets safeInsets;

  @override
  State<_LogDetailDialog> createState() => _LogDetailDialogState();
}

class _LogDetailDialogState extends State<_LogDetailDialog> {
  final TextEditingController _searchController = TextEditingController();
  // onKeyEvent 先于 TextField 自身处理：回车 / 方向键在这里被拦下用于跳转
  late final FocusNode _searchFocus = FocusNode(onKeyEvent: _handleSearchKey);

  /// 当前命中处的定位 key（由 [mxHighlightSpans] 挂在零尺寸占位上），
  /// 跳转时用它 ensureVisible
  final GlobalKey _activeKey = GlobalKey();

  Timer? _debounce;
  String _query = "";
  int _total = 0;

  /// 当前命中序号（-1 为无）
  int _active = -1;

  /// 正文若为 JSON 只解析一次，命中计数与树渲染共用
  late final Object? _json = mxTryParseJson(widget.log.msg);

  LogModel get log => widget.log;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    // 清空立即生效；输入中 150ms 防抖，超长正文每个字符都重算高亮会卡
    if (text.isEmpty) {
      _applyQuery("");
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () => _applyQuery(text));
  }

  void _applyQuery(String query) {
    if (!mounted) return;
    final Object? json = _json;
    final int total = json != null
        ? mxJsonMatchCount(json, query)
        : mxCountMatches(log.msg ?? "", query);
    setState(() {
      _query = query;
      _total = total;
      _active = total > 0 ? 0 : -1;
    });
    _revealActive();
  }

  /// 上一处 / 下一处，首尾循环
  void _step(int delta) {
    if (_total == 0) return;
    setState(() => _active = (_active + delta + _total) % _total);
    _revealActive();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _applyQuery("");
  }

  /// 当前命中的占位在本帧重建后才有位置，下一帧再滚到它（落在视口约 30% 处）
  void _revealActive() {
    if (_active < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? target = _activeKey.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  KeyEventResult _handleSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _step(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    // 有搜索内容时 Esc 先清空搜索，再按一次才关弹窗
    if (key == LogicalKeyboardKey.escape && _searchController.text.isNotEmpty) {
      _clearSearch();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color levelColor = tokens.levelColor(log.level);
    final MxTimeParts time = log.timeParts;
    final bool isJson = _json != null;
    // 移动端铺满整屏（设计稿 720px 断点：宽高 100%、无圆角、无左右描边）
    final bool mobile = context.isMobileLayout;

    final TextStyle labelStyle = TextStyle(fontSize: 12.5, color: tokens.faint);
    final TextStyle valueStyle = TextStyle(
      fontSize: 12.5,
      color: tokens.text,
      fontFamilyFallback: MXTheme.monoFontFallback,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 880),
        // 圆角容器内嵌顶部等级色条（非均匀 Border 不能与圆角共存）
        child: Container(
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: mobile ? BorderRadius.zero : BorderRadius.circular(14),
            border: mobile ? null : Border.all(color: tokens.border),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 24), blurRadius: 70),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsets.only(top: mobile ? widget.safeInsets.top : 0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: levelColor, width: 3)),
            ),
            child: Column(
            mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                child: Row(
                  children: [
                    LevelBadge(level: log.level),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: "${time.date} ${time.time}"),
                          TextSpan(text: ".${time.ms}", style: TextStyle(color: tokens.faint)),
                        ]),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tokens.muted,
                          fontFamilyFallback: MXTheme.monoFontFallback,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 16, color: tokens.muted),
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
              Divider(color: tokens.border),
              _searchBar(context, tokens, mobile: mobile),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.border, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _fieldRow(context.l10n.fieldName, "@${log.name ?? "-"}",
                                labelStyle, valueStyle),
                            _fieldRow(
                                context.l10n.fieldTags,
                                log.tags.map((String t) => "#$t").join("  "),
                                labelStyle,
                                valueStyle),
                            _fieldRow(context.l10n.fieldTime, time.full, labelStyle, valueStyle),
                            _fieldRow(
                                context.l10n.fieldKind,
                                isJson ? context.l10n.kindJson : context.l10n.kindText,
                                labelStyle,
                                valueStyle),
                          ],
                        ),
                      ),
                      LogBody(
                        log: log,
                        query: _query,
                        fullExpand: true,
                        activeMatch: _active,
                        activeKey: _activeKey,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: tokens.border),
              Padding(
                // 移动端底栏避让 home indicator（设计稿 modal-foot）
                padding: EdgeInsets.fromLTRB(
                    18, 10, 18, 10 + (mobile ? widget.safeInsets.bottom : 0)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 移动端三个按钮等宽平分整行，便于单手点击（设计稿 modal-foot button flex:1）
                    _FooterButton(
                      label: context.l10n.share,
                      expand: mobile,
                      onTap: () => mxShare(
                        context,
                        title: context.l10n.shareExportTitle,
                        text: log.toShareText(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FooterButton(
                      label: context.l10n.copyLog,
                      expand: mobile,
                      onTap: () => copyLog(context, MXScope.of(context), log),
                    ),
                    const SizedBox(width: 8),
                    _FooterButton(
                      label: mobile ? context.l10n.close : context.l10n.closeEsc,
                      expand: mobile,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 正文内搜索栏：输入框（含命中计数与清除）+ 上一处 / 下一处
  Widget _searchBar(BuildContext context, MXTokens tokens, {required bool mobile}) {
    final double fontSize = context.mxInputFontSize(13);
    final bool hasQuery = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: mobile ? 40 : 32,
              decoration: BoxDecoration(
                color: tokens.panel2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 9),
                  Icon(Icons.search, size: 15, color: tokens.faint),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      // 桌面端打开即可直接输入；手机端不自动弹键盘，先看内容
                      autofocus: !mobile,
                      onChanged: _onSearchChanged,
                      style: TextStyle(fontSize: fontSize, color: tokens.text),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: context.l10n.detailSearchHint,
                        hintStyle: TextStyle(
                            fontSize: fontSize, color: tokens.faint.withValues(alpha: 0.7)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        _total > 0
                            ? context.l10n.matchPosition(_active + 1, _total)
                            : context.l10n.searchNoMatch,
                        style: TextStyle(
                          fontSize: 12,
                          color: _total > 0 ? tokens.muted : tokens.lvWarning,
                          fontFamilyFallback: MXTheme.monoFontFallback,
                        ),
                      ),
                    ),
                  if (hasQuery)
                    _SearchIconButton(
                      tooltip: context.l10n.clearSearchTip,
                      icon: Icons.close,
                      onTap: _clearSearch,
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SearchIconButton(
            tooltip: context.l10n.matchPrevTip,
            icon: Icons.keyboard_arrow_up,
            boxed: true,
            enabled: _total > 0,
            onTap: () => _step(-1),
          ),
          const SizedBox(width: 4),
          _SearchIconButton(
            tooltip: context.l10n.matchNextTip,
            icon: Icons.keyboard_arrow_down,
            boxed: true,
            enabled: _total > 0,
            onTap: () => _step(1),
          ),
        ],
      ),
    );
  }

  Widget _fieldRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Text(label, style: labelStyle)),
          const SizedBox(width: 14),
          Expanded(child: SelectableText(value, style: valueStyle)),
        ],
      ),
    );
  }
}

class _FooterButton extends StatefulWidget {
  const _FooterButton({required this.label, required this.onTap, this.expand = false});

  final String label;
  final VoidCallback onTap;

  /// 移动端等宽平分底栏
  final bool expand;

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.expand ? 11 : 7),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovering ? tokens.faint : tokens.border),
          ),
          alignment: widget.expand ? Alignment.center : null,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
    return widget.expand ? Expanded(child: button) : button;
  }
}

/// 搜索栏小图标按钮：[boxed] 为带边框方块（上一处 / 下一处），否则为输入框内裸图标（清除）。
class _SearchIconButton extends StatefulWidget {
  const _SearchIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.boxed = false,
    this.enabled = true,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool boxed;
  final bool enabled;

  @override
  State<_SearchIconButton> createState() => _SearchIconButtonState();
}

class _SearchIconButtonState extends State<_SearchIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool active = widget.enabled && _hovering;
    final Color iconColor = !widget.enabled
        ? tokens.faint.withValues(alpha: 0.4)
        : (active ? tokens.text : tokens.muted);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.enabled ? widget.onTap : null,
          child: Container(
            width: widget.boxed ? 32 : 24,
            height: widget.boxed ? 32 : 24,
            decoration: widget.boxed
                ? BoxDecoration(
                    color: active ? tokens.border : tokens.panel2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? tokens.faint : tokens.border),
                  )
                : null,
            child: Icon(widget.icon, size: widget.boxed ? 18 : 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}
