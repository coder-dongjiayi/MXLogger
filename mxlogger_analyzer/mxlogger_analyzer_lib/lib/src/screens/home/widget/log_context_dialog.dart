import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/level_badge.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';

/// 上下文面板：以某条日志为锚点，展示它在**全部日志**里前后各 N 条（忽略当前筛选），
/// 顶部 / 底部可继续往远处加载。筛出一堆 ERROR 之后想知道某条前后发生了什么，
/// 不必清掉筛选再去全局大海捞针。
///
/// 排列顺序跟随列表当前的正 / 倒序，锚点卡片以强调色描边高亮。Esc / 点击遮罩关闭。
Future<void> showLogContextDialog(BuildContext context, {required LogModel log}) {
  final MXTokens tokens = MXTokens.of(context);
  // Dialog 内部会清掉 MediaQuery padding，安全区在弹出前从宿主 context 取
  final EdgeInsets safeInsets = MediaQuery.viewPaddingOf(context);
  return showDialog<void>(
    context: context,
    barrierColor: tokens.mask,
    // 就近 Navigator：嵌入模式下 MXScope / 主题 / l10n 都在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    // 移动端弹窗铺满整屏（底色盖到刘海下），安全区由弹窗内部留白避让
    useSafeArea: !context.isMobileLayout,
    builder: (BuildContext context) =>
        LogContextDialog(anchor: log, safeInsets: safeInsets),
  );
}

class LogContextDialog extends MXConsumerStatefulWidget {
  const LogContextDialog({
    super.key,
    required this.anchor,
    required this.safeInsets,
    this.pageSize = 20,
  });

  final LogModel anchor;

  /// 宿主屏幕安全区（移动端弹窗铺满时用于避让状态栏 / home indicator）
  final EdgeInsets safeInsets;

  /// 初始前后各取的条数，也是每次「加载更多」的步长
  final int pageSize;

  @override
  MXConsumerState<LogContextDialog> createState() => _LogContextDialogState();
}

class _LogContextDialogState extends MXConsumerState<LogContextDialog> {
  /// CustomScrollView 的中心 sliver：锚点卡片固定在滚动偏移 0 处，
  /// 往前翻加载的日志挂在它上方（负偏移区），不会把锚点顶走。
  static const Key _centerKey = ValueKey<String>("mx_context_anchor");

  final ScrollController _controller = ScrollController();

  /// 比锚点更早 / 更新的日志，均按「离锚点由近到远」排列
  List<LogModel> _older = const [];
  List<LogModel> _newer = const [];

  /// 全局比锚点更早的条数与全局总条数（算「第 N 条 / 共 M 条」）
  int _olderCount = 0;
  int _total = 0;

  bool _loading = true;
  bool _failed = false;

  /// 上次取到的条数不足一页即视为到头，不再显示「加载更多」
  bool _olderExhausted = false;
  bool _newerExhausted = false;
  bool _loadingOlder = false;
  bool _loadingNewer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final LogContext result =
          await store.repository.fetchContext(widget.anchor, limit: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _older = result.older;
        _newer = result.newer;
        _olderCount = result.olderCount;
        _total = result.total;
        _olderExhausted = result.older.length < widget.pageSize;
        _newerExhausted = result.newer.length < widget.pageSize;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _olderExhausted) return;
    // 以当前最远一条为游标继续往前取
    final int edge = _older.isEmpty ? widget.anchor.timestamp : _older.last.timestamp;
    setState(() => _loadingOlder = true);
    try {
      final List<LogModel> more =
          await store.repository.fetchOlderThan(edge, limit: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _older = [..._older, ...more];
        _olderExhausted = more.length < widget.pageSize;
        _loadingOlder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
      showMXToast(context, context.l10n.contextLoadFailed);
    }
  }

  Future<void> _loadNewer() async {
    if (_loadingNewer || _newerExhausted) return;
    final int edge = _newer.isEmpty ? widget.anchor.timestamp : _newer.last.timestamp;
    setState(() => _loadingNewer = true);
    try {
      final List<LogModel> more =
          await store.repository.fetchNewerThan(edge, limit: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _newer = [..._newer, ...more];
        _newerExhausted = more.length < widget.pageSize;
        _loadingNewer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNewer = false);
      showMXToast(context, context.l10n.contextLoadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool mobile = context.isMobileLayout;
    final LogFilterState filter = ref.watch(store.filter);
    // 与列表同向：倒序时更新的在上、更早的在下
    final bool descending = !filter.ascending;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 960),
        child: Container(
          padding: EdgeInsets.only(
            top: mobile ? widget.safeInsets.top : 0,
            bottom: mobile ? widget.safeInsets.bottom : 0,
          ),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: mobile ? BorderRadius.zero : BorderRadius.circular(14),
            border: mobile ? null : Border.all(color: tokens.border),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 24), blurRadius: 70),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, tokens, descending: descending),
              Divider(height: 1, color: tokens.border),
              Expanded(child: _body(context, tokens, descending: descending)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, MXTokens tokens, {required bool descending}) {
    final MxTimeParts time = widget.anchor.timeParts;
    // 显示序号按当前排列方向数：倒序时最新的是第 1 条
    final int index = descending ? _total - _olderCount : _olderCount + 1;
    final TextStyle subStyle = TextStyle(fontSize: 12, color: tokens.faint);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 10),
      child: Row(
        children: [
          Icon(Icons.unfold_more, size: 18, color: tokens.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      context.l10n.contextTitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens.panel2,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Text(context.l10n.contextIgnoresFilters, style: subStyle),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LevelBadge(level: widget.anchor.level),
                    Text(
                      "${time.date} ${time.time}.${time.ms}",
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.muted,
                        fontFamilyFallback: MXTheme.monoFontFallback,
                      ),
                    ),
                    if (!_loading && !_failed)
                      Text(context.l10n.contextPosition(index, _total), style: subStyle),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, size: 16, color: tokens.muted),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, MXTokens tokens, {required bool descending}) {
    if (_loading) {
      return const Center(
        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.contextLoadFailed,
                style: TextStyle(fontSize: 13, color: tokens.faint)),
            const SizedBox(height: 12),
            _PillButton(label: context.l10n.retry, onTap: _load),
          ],
        ),
      );
    }

    final List<LogModel> above = descending ? _newer : _older;
    final List<LogModel> below = descending ? _older : _newer;
    final double padX = context.isMobileLayout ? 6 : 18;
    final EdgeInsets cardPad = EdgeInsets.fromLTRB(padX, 0, padX, 8);

    // center 之前的 sliver 逆向排布：列表里越靠前的越远离锚点，
    // 所以「上方边缘控件」放第一位，上方日志列表 index 0 紧贴锚点。
    return CustomScrollView(
      controller: _controller,
      center: _centerKey,
      // 锚点初始落在视口约 1/3 处，上下文两头都能先看到一些
      anchor: 0.3,
      slivers: [
        SliverToBoxAdapter(
          child: _edge(context, tokens, newer: descending, top: true),
        ),
        SliverList.builder(
          itemCount: above.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: cardPad,
            child: LogCard(log: above[index], showContext: false),
          ),
        ),
        SliverToBoxAdapter(
          key: _centerKey,
          child: Padding(
            padding: cardPad,
            child: LogCard(log: widget.anchor, anchored: true, showContext: false),
          ),
        ),
        SliverList.builder(
          itemCount: below.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: cardPad,
            child: LogCard(log: below[index], showContext: false),
          ),
        ),
        SliverToBoxAdapter(
          child: _edge(context, tokens, newer: !descending, top: false),
        ),
      ],
    );
  }

  /// 列表两端的控件：到头提示 / 加载中 / 「再加载 N 条」按钮。
  /// [newer] 指这一端朝向更新的日志。
  Widget _edge(BuildContext context, MXTokens tokens, {required bool newer, required bool top}) {
    final bool exhausted = newer ? _newerExhausted : _olderExhausted;
    final bool loading = newer ? _loadingNewer : _loadingOlder;
    final Widget child;
    if (exhausted) {
      child = Text(
        newer ? context.l10n.contextNoNewer : context.l10n.contextNoOlder,
        style: TextStyle(fontSize: 12, color: tokens.faint),
      );
    } else if (loading) {
      child = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      child = _PillButton(
        label: newer
            ? context.l10n.contextLoadNewer(widget.pageSize)
            : context.l10n.contextLoadOlder(widget.pageSize),
        onTap: newer ? _loadNewer : _loadOlder,
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: top ? 14 : 6, bottom: top ? 14 : 18),
      child: Center(child: child),
    );
  }
}

/// 胶囊按钮（与列表内「查看完整」按钮同款）。
class _PillButton extends StatefulWidget {
  const _PillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: tokens.panel2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hovering ? tokens.faint : tokens.border),
            boxShadow: tokens.cardShadow,
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: _hovering ? tokens.text : tokens.muted),
          ),
        ),
      ),
    );
  }
}
