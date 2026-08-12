import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_share.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/highlight_text.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/json_tree.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/level_badge.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/header_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_detail_dialog.dart';

/// 手机端卡片头部的紧凑尺寸：手机屏窄，折叠钮左边距、折叠钮宽度、
/// 元素间距都压到最小，省下的宽度留给时间/tag/正文。
const double _headPadXMobile = 6;
const double _foldSizeMobile = 16;
const double _headGapMobile = 5;

/// 正文/预览的左缩进 = 头部左边距 + 折叠钮宽 + 间距，与等级徽标左对齐
const double _bodyIndentMobile = _headPadXMobile + _foldSizeMobile + _headGapMobile;

/// 日志卡片（对齐设计稿）：左侧等级色条 + 头部（折叠钮/等级/时间/@name/#tags/操作）
/// + 折叠单行预览或展开正文（JSON 树 / 高亮文本）。FATAL 卡片带品红描边光。
class LogCard extends MXConsumerWidget {
  const LogCard({super.key, required this.log});

  final LogModel log;

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final LogFilterState filter = ref.watch(ref.store.filter);
    // 折叠态 = 默认态 异或 本条是否被单独翻转过
    // （只 select 自己那一位：别的卡片折叠不触发本卡片重建）
    final bool foldByDefault = ref.watch(ref.store.allCollapsed);
    final bool toggled =
        ref.select(ref.store.foldToggled, (Set<int> set) => set.contains(log.id));
    final bool collapsed = toggled ? !foldByDefault : foldByDefault;
    final Color levelColor = tokens.levelColor(log.level);
    final MxTimeParts time = log.timeParts;
    final bool mobile = context.isMobileLayout;

    final String query = filter.keyword;
    final bool hlContent =
        query.isNotEmpty && (filter.scope == MxSearchScope.all || filter.scope == MxSearchScope.content);
    final bool hlTag =
        query.isNotEmpty && (filter.scope == MxSearchScope.all || filter.scope == MxSearchScope.tag);
    final bool hlName =
        query.isNotEmpty && (filter.scope == MxSearchScope.all || filter.scope == MxSearchScope.name);

    // 圆角容器内嵌左侧等级色条（非均匀 Border 不能与圆角共存）
    return Container(
      decoration: BoxDecoration(
        color: tokens.panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tokens.border),
        boxShadow: [
          ...tokens.cardShadow,
          // FATAL 品红描边光（对齐设计稿 fatalGlow）
          if (log.level == 4)
            BoxShadow(color: tokens.lvFatal.withValues(alpha: 0.35), spreadRadius: 1),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: levelColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          InkWell(
            onTap: () => _toggleFold(ref.store),
            child: Padding(
              // 移动端各处收窄：屏幕窄，留白吃的都是日志正文宽度
              padding: mobile
                  ? const EdgeInsets.fromLTRB(_headPadXMobile, 10, 8, 8)
                  : const EdgeInsets.fromLTRB(14, 9, 14, 7),
              // 标签区流式换行占满剩余宽度，操作按钮固定靠 end。
              // 折叠钮独立在 Wrap 之外：换行的 tag 才会跟等级徽标左对齐，
              // 而不是缩回到折叠箭头下面
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FoldButton(
                    collapsed: collapsed,
                    width: mobile ? _foldSizeMobile : 24,
                    onTap: () => _toggleFold(ref.store),
                  ),
                  SizedBox(width: mobile ? _headGapMobile : 10),
                  Expanded(
                    child: Wrap(
                      spacing: mobile ? _headGapMobile : 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        LevelBadge(level: log.level),
                        Text.rich(
                          TextSpan(children: [
                            // 时间恒显示完整年月日时分秒（毫秒跟在后面）：
                            // 排查问题时只有时分秒不够用
                            TextSpan(text: "${time.date} ${time.time}"),
                            TextSpan(
                                text: ".${time.ms}",
                                style: TextStyle(color: tokens.faint)),
                          ]),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: tokens.muted,
                            fontFamilyFallback: MXTheme.monoFontFallback,
                          ),
                        ),
                        _NameButton(log: log, highlight: hlName ? query : ""),
                        for (final String tag in log.tags)
                          _TagButton(tag: tag, highlight: hlTag ? query : ""),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _actions(context, ref, tokens),
                ],
              ),
            ),
          ),
            if (collapsed)
              _preview(context, ref.store, tokens, hlContent ? query : "")
            else
              Padding(
                // 与折叠预览左对齐一致（缩进到等级徽标之后：头部左边距 + 折叠钮 + 间距）
                padding: mobile
                    ? const EdgeInsets.fromLTRB(_bodyIndentMobile, 2, 8, 11)
                    : const EdgeInsets.fromLTRB(48, 2, 14, 11),
                child: _ClampedBody(log: log, query: hlContent ? query : ""),
              ),
          ],
        ),
      ),
    );
  }

  /// 翻转本条相对默认折叠态的状态（再翻一次即回到跟随默认）
  void _toggleFold(MXStore store) {
    final Set<int> next = Set<int>.from(store.foldToggled.value);
    final int id = log.id ?? -1;
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    store.foldToggled.value = next;
  }

  Widget _actions(BuildContext context, MXRef ref, MXTokens tokens) {
    final bool copied = ref.watch(ref.store.copiedId) == log.id;
    final bool hasHeader = (log.fileHeader?.trim().isNotEmpty) ?? false;
    // 手机上 4 个图标要占掉大半行宽度，收进「⋯」里，点开从底部弹出
    if (context.isMobileLayout) {
      return _RowIconButton(
        tooltip: context.l10n.moreActions,
        icon: Icons.more_horiz,
        iconColor: copied ? tokens.jsonStr : null,
        // 比其它手机端按钮更小：它挤在时间/tag 同一行，不该抢视觉
        size: 26,
        onTap: () => _showActionsSheet(context, ref.store, hasHeader: hasHeader),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 每条日志对应各自文件的 Header，点开查看（无 header 的日志不显示）
        if (hasHeader) ...[
          _RowIconButton(
            tooltip: context.l10n.headerRowTip,
            icon: Icons.info_outline,
            onTap: () => showLogHeaderDialog(context, log: log),
          ),
          const SizedBox(width: 5),
        ],
        _RowIconButton(
          tooltip: context.l10n.shareRowTip,
          icon: Icons.share_outlined,
          onTap: () => mxShare(
            context,
            title: context.l10n.shareExportTitle,
            text: log.toShareText(),
          ),
        ),
        const SizedBox(width: 5),
        _RowIconButton(
          tooltip: context.l10n.fullscreenTip,
          icon: Icons.fullscreen,
          onTap: () => showLogDetailDialog(context, log: log),
        ),
        const SizedBox(width: 5),
        _RowIconButton(
          tooltip: context.l10n.copyRowTip,
          icon: copied ? Icons.check : Icons.copy_outlined,
          iconColor: copied ? tokens.jsonStr : null,
          onTap: () => copyLog(context, ref.store, log),
        ),
      ],
    );
  }

  /// 手机端「⋮」的操作面板：Header / 分享 / 全屏 / 复制。
  /// 走就近 Navigator，嵌入模式下才留在分析器自己的主题与 MXScope 里。
  Future<void> _showActionsSheet(
    BuildContext context,
    MXStore store, {
    required bool hasHeader,
  }) async {
    final MXTokens tokens = MXTokens.of(context);
    final double safeBottom = context.mxSafeBottom;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      barrierColor: tokens.mask,
      builder: (BuildContext sheetContext) {
        void run(VoidCallback action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return Container(
          padding: EdgeInsets.only(top: 8, bottom: 8 + safeBottom),
          decoration: BoxDecoration(
            color: tokens.panel,
            border: Border(top: BorderSide(color: tokens.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 抓手条：提示可下滑关闭
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: tokens.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (hasHeader)
                _SheetAction(
                  icon: Icons.info_outline,
                  label: context.l10n.headerRowTip,
                  onTap: () => run(() => showLogHeaderDialog(context, log: log)),
                ),
              _SheetAction(
                icon: Icons.share_outlined,
                label: context.l10n.shareRowTip,
                onTap: () => run(() => mxShare(
                      context,
                      title: context.l10n.shareExportTitle,
                      text: log.toShareText(),
                    )),
              ),
              _SheetAction(
                icon: Icons.fullscreen,
                label: context.l10n.fullscreenTip,
                onTap: () => run(() => showLogDetailDialog(context, log: log)),
              ),
              _SheetAction(
                icon: Icons.copy_outlined,
                label: context.l10n.copyRowTip,
                onTap: () => run(() => copyLog(context, store, log)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _preview(BuildContext context, MXStore store, MXTokens tokens, String query) {
    return Tooltip(
      message: context.l10n.clickExpandTip,
      waitDuration: const Duration(milliseconds: 800),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _toggleFold(store),
          child: Padding(
            padding: context.isMobileLayout
                ? const EdgeInsets.fromLTRB(_bodyIndentMobile, 0, 8, 9)
                : const EdgeInsets.fromLTRB(48, 0, 14, 9),
            child: Text.rich(
              TextSpan(
                children: mxHighlightSpans(
                  log.preview,
                  query,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.text,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                  tokens: tokens,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// 复制单条日志并短暂显示对勾（对齐设计稿 copyLog）。
Future<void> copyLog(BuildContext context, MXStore store, LogModel log) async {
  await Clipboard.setData(ClipboardData(text: log.toShareText()));
  if (!context.mounted) return;
  showMXToast(context, context.l10n.copied);
  store.copiedId.value = log.id;
  Future.delayed(const Duration(milliseconds: 1200), () {
    // 延时回调时 store 可能已随嵌入弹窗释放
    if (store.copiedId.isDisposed) return;
    if (store.copiedId.value == log.id) store.copiedId.value = null;
  });
}

/// 日志正文：JSON → 徽标 + 语法树；纯文本 → 等宽 pre-wrap（带高亮）。
class LogBody extends StatelessWidget {
  const LogBody({super.key, required this.log, required this.query, this.fullExpand = false});

  final LogModel log;
  final String query;

  /// 全屏弹窗中完整展开 JSON
  final bool fullExpand;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Object? json = mxTryParseJson(log.msg);
    if (json != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tokens.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: tokens.border),
        ),
        child: JsonTree(value: json, autoDepth: fullExpand ? 99 : 2, query: query),
      );
    }
    return SelectableText.rich(
      TextSpan(
        children: mxHighlightSpans(
          log.msg ?? "",
          query,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.65,
            color: tokens.text,
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
          tokens: tokens,
        ),
      ),
    );
  }
}

/// 列表内展开正文的限高容器：正文超过 [maxHeight] 时裁剪显示，
/// 底部渐隐并浮出「查看完整」按钮（进全屏弹窗），避免超长日志撑爆列表。
class _ClampedBody extends StatefulWidget {
  const _ClampedBody({required this.log, required this.query});

  final LogModel log;
  final String query;

  /// 正文最大显示高度，超出即渐隐截断
  static const double maxHeight = 280;

  @override
  State<_ClampedBody> createState() => _ClampedBodyState();
}

class _ClampedBodyState extends State<_ClampedBody> {
  final ScrollController _controller = ScrollController();
  bool _overflowed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// JSON 树节点展开、关键词高亮都会改变正文高度，每次布局后复查是否溢出
  void _scheduleOverflowCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final bool overflowed = _controller.position.maxScrollExtent > 0;
      if (overflowed != _overflowed) setState(() => _overflowed = overflowed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    _scheduleOverflowCheck();
    // JSON 正文自带 tokens.bg 底色的容器，渐隐取同色才能无缝衔接
    final Color fadeColor =
        mxTryParseJson(widget.log.msg) != null ? tokens.bg : tokens.panel;
    return Stack(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _ClampedBody.maxHeight),
          child: SingleChildScrollView(
            controller: _controller,
            // 禁用滚动：仅借 maxScrollExtent 判断溢出，避免劫持列表滚轮
            physics: const NeverScrollableScrollPhysics(),
            child: LogBody(log: widget.log, query: widget.query),
          ),
        ),
        if (_overflowed) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fadeColor.withValues(alpha: 0), fadeColor],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Center(child: _ViewFullButton(log: widget.log)),
          ),
        ],
      ],
    );
  }
}

/// 限高截断处的「查看完整（共 N 行）」按钮，点击进全屏弹窗。
class _ViewFullButton extends StatefulWidget {
  const _ViewFullButton({required this.log});

  final LogModel log;

  @override
  State<_ViewFullButton> createState() => _ViewFullButtonState();
}

class _ViewFullButtonState extends State<_ViewFullButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: () => showLogDetailDialog(context, log: widget.log),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: tokens.panel2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hovering ? tokens.faint : tokens.border),
            boxShadow: tokens.cardShadow,
          ),
          child: Text(
            context.l10n.viewFullLog(mxLineCountOf(widget.log.msg)),
            style: TextStyle(
              fontSize: 12,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldButton extends StatelessWidget {
  const _FoldButton({
    required this.collapsed,
    required this.onTap,
    this.width = 24,
  });

  final bool collapsed;
  final VoidCallback onTap;

  /// 命中区宽度（手机端压窄，紧贴等级徽标）
  final double width;

  /// 高度固定为标签行高：折叠钮在 Wrap 之外，靠这个高度与首行徽标对齐
  static const double _lineHeight = 20;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Tooltip(
      message: collapsed ? context.l10n.unfoldTip : context.l10n.foldTip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: _lineHeight,
            child: Center(
              child: AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: const Duration(milliseconds: 150),
                child: Text("▾", style: TextStyle(fontSize: 12, color: tokens.muted)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// @name 按钮：点击按 name 过滤（再点取消）。
class _NameButton extends MXConsumerWidget {
  const _NameButton({required this.log, required this.highlight});

  final LogModel log;
  final String highlight;

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final String name = log.name ?? "-";
    return Tooltip(
      message: context.l10n.filterByNameTip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            ref.store.filter.update((LogFilterState state) => state.toggleName(name));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: tokens.nameText.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: "@",
                  style: TextStyle(color: tokens.nameText.withValues(alpha: 0.55)),
                ),
                ...mxHighlightSpans(
                  name,
                  highlight,
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.nameText,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                  tokens: tokens,
                ),
              ]),
              style: TextStyle(
                fontSize: 12,
                color: tokens.nameText,
                fontFamilyFallback: MXTheme.monoFontFallback,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// #tag 按钮：点击按 tag 过滤（再点取消）。
class _TagButton extends MXConsumerStatefulWidget {
  const _TagButton({required this.tag, required this.highlight});

  final String tag;
  final String highlight;

  @override
  MXConsumerState<_TagButton> createState() => _TagButtonState();
}

class _TagButtonState extends MXConsumerState<_TagButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Tooltip(
      message: context.l10n.filterByTagTip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () {
            store.filter.update((LogFilterState state) => state.toggleTag(widget.tag));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              color: tokens.panel2,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _hovering ? tokens.faint : Colors.transparent),
            ),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: "#",
                    style: TextStyle(color: tokens.tagText.withValues(alpha: 0.6))),
                ...mxHighlightSpans(
                  widget.tag,
                  widget.highlight,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _hovering ? tokens.text : tokens.tagText,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                  tokens: tokens,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 手机端操作面板的一行：图标 + 文案，整行可点（高度够手指点）。
class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: tokens.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: tokens.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片头部 28x28 操作小按钮。
class _RowIconButton extends StatefulWidget {
  const _RowIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  /// 不传则按端上默认尺寸（桌面 28 / 手机 36）
  final double? size;

  @override
  State<_RowIconButton> createState() => _RowIconButtonState();
}

class _RowIconButtonState extends State<_RowIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    // 移动端加大到 36（设计稿 row-head button）
    final double size = widget.size ?? context.mxRowButtonSize;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: _hovering ? tokens.border : tokens.panel2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _hovering ? tokens.faint : tokens.border),
            ),
            child: Icon(
              widget.icon,
              size: size * 0.5,
              color: widget.iconColor ?? (_hovering ? tokens.text : tokens.muted),
            ),
          ),
        ),
      ),
    );
  }
}
