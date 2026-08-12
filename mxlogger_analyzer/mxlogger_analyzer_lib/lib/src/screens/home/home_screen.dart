import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/screen_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_collapsible.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_icon_button.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_pulse_grid.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_page_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/active_filters.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_header.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_toolbar.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/dialog/crypt_confirm_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/import_loading_view.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/time_panel.dart';

/// 选择日志文件并触发导入（数据页空态与 header「更换文件」共用）。
/// 选择能力由宿主注入（桌面壳用 file_picker 实现），未注入时不动作。
/// 选到 .mx 文件时先弹 Key/IV 确认框（代入上次值），确认后再解析。
Future<void> pickAndImportLogFiles(BuildContext context, MXStore store) async {
  final MXPickLogFiles? pickLogFiles = store.host.pickLogFiles;
  if (pickLogFiles == null) return;
  final List<String> paths = await pickLogFiles();
  if (paths.isEmpty) return;

  // .mx 为加密二进制，解析前确认 Key/IV 并选择是否清空已有数据；
  // 纯文本格式无加密，直接追加导入
  bool clearExisting = false;
  final bool hasMx = paths.any((String p) => p.toLowerCase().endsWith(".mx"));
  if (hasMx) {
    if (!context.mounted) return;
    final CryptConfirmResult? result = await showCryptConfirmDialog(context);
    if (result == null) return;
    clearExisting = result.clearExisting;
  }
  store.importer.importFiles(paths, clearExisting: clearExisting);
}

/// 嵌入模式「刷新」：清空数据库 + 重新全量解析宿主 app 的日志目录。
/// 目录里没有可解析文件时 toast 提示。
Future<void> refreshDeviceLogs(BuildContext context, MXStore store) async {
  final String? diskcachePath = store.diskcachePath;
  if (diskcachePath == null) return;
  final bool found = await store.importer.importFromDirectory(diskcachePath);
  if (!found && context.mounted) {
    showMXToast(context, context.l10n.noLogFiles);
  }
}

/// 数据页（对齐设计稿页面二）：
/// 导入中 → 真实进度 loading；无数据 → 拖入/选择日志空态；有数据 → 完整解析视图。
class HomeScreen extends MXConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends MXConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _dragover = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 手机端一屏放不下几条展开的日志，默认全部折叠（只显示单行预览）。
  /// 只在首帧生效一次，之后用户点「展开全部」的选择不会被覆盖。
  bool _foldDefaultApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_foldDefaultApplied || !context.isMobileLayout) return;
    _foldDefaultApplied = true;
    store.allCollapsed.value = true;
  }

  /// 滚动接近底部时加载下一页（store 内部有 loadingMore/hasMore 防重入）
  void _maybeLoadMore() {
    if (_scrollController.position.extentAfter < 200) {
      store.logList.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ImportState importState = ref.watch(store.importer);
    final MXAsync<HeaderInfo> headerInfo = ref.watch(store.headerInfo);

    final Widget body;
    if (importState.isRunning || importState.status == ImportStatus.success) {
      // success 到复位之间的过渡帧继续显示 loading，避免闪现空态卡片
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ImportLoadingView(state: importState),
        ),
      );
    } else if (headerInfo.isLoading && !headerInfo.hasValue) {
      // 统计首帧未就绪时不能当成「无数据」，否则重新打开应用会
      // 闪现一下选择日志的空态卡片再切到数据页
      body = const SizedBox.expand();
    } else if ((headerInfo.valueOrNull?.total ?? 0) == 0) {
      // 嵌入模式日志来源固定为本机目录：空态不给拖入/选择文件，
      // 只给「刷新」让用户自己触发解析
      body = store.isEmbedded
          ? const _EmbedEmptyState()
          : _EmptyDropState(dragover: _dragover);
    } else {
      body = _dataBody();
    }

    // 拖入能力由宿主注入（桌面壳用 desktop_drop 实现），未注入时原样渲染
    return store.host.wrapDropTarget(
      onDragOver: (bool over) => setState(() => _dragover = over),
      onDrop: (List<String> paths) {
        setState(() => _dragover = false);
        if (paths.isEmpty) return;
        store.importer.importFiles(paths);
      },
      child: body,
    );
  }

  Widget _dataBody() {
    final bool timeOpen = ref.watch(store.timeOpen);
    final bool mobile = context.isMobileLayout;
    final bool headerCollapsed = mobile && ref.watch(store.headerCollapsed);
    final double fabInset = mobile ? 16 : 18;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 品牌行与右上角操作始终可见；等级筛选区在 DataHeader 内部一起收
            const DataHeader(),
            // 搜索 / 时间范围 / 折叠全部 + 时间面板，跟等级筛选区一起收起
            MXCollapsible(
              collapsed: headerCollapsed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DataToolbar(),
                  if (timeOpen) const TimePanel(),
                ],
              ),
            ),
            const ActiveFilters(),
            Expanded(child: _logList()),
          ],
        ),
        // 手机端左下角：收起/展开筛选区，把整屏让给日志
        if (mobile)
          Positioned(
            left: fabInset,
            bottom: fabInset + context.mxSafeBottom,
            child: _RoundFabButton(
              tooltip: headerCollapsed
                  ? context.l10n.expandFilters
                  : context.l10n.collapseFilters,
              icon: headerCollapsed ? Icons.expand_more : Icons.expand_less,
              onTap: () => store.headerCollapsed.value = !headerCollapsed,
            ),
          ),
        // 悬浮按钮避让底部安全区（嵌入手机 app 时贴着 home indicator）
        Positioned(
          right: fabInset,
          bottom: fabInset + context.mxSafeBottom,
          child: _jumpButtons(),
        ),
      ],
    );
  }

  Widget _logList() {
    final MXTokens tokens = MXTokens.of(context);
    final LogPageState page =
        ref.watch(store.logList).valueOrNull ?? const LogPageState();
    final List<LogModel> logs = page.logs;
    final LogFilterState filter = ref.watch(store.filter);
    final int total = ref
        .watch(store.levelCounts)
        .valueOrNull
        ?.values
        .fold<int>(0, (int sum, int c) => sum + c) ??
        0;

    String resultLine = filter.hasFilter
        ? context.l10n.resultMatch(page.total, total)
        : context.l10n.resultTotal(page.total);

    // 起止时间跟在条数后面（原 header 统计区移到这里），样式与条数一致
    final HeaderInfo info =
        ref.watch(store.headerInfo).valueOrNull ?? const HeaderInfo();
    if (info.minUs != null && info.maxUs != null) {
      String timeOf(int? us) =>
          mxFmtTs(DateTime.fromMicrosecondsSinceEpoch(us ?? 0)).full;
      resultLine += "  ·  ${context.l10n.statStart} ${timeOf(info.minUs)}"
          "  ·  ${context.l10n.statEnd} ${timeOf(info.maxUs)}";
    }

    if (logs.isEmpty && filter.hasFilter) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resultLineRow(tokens, resultLine),
          Expanded(child: _noResult(tokens)),
        ],
      );
    }

    // 未加载完时末尾多一项加载 footer：既是分页动画，也兜底触发加载
    // （首页不满一屏时滚动监听不会触发）
    final bool showFooter = page.hasMore || page.loadingMore;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _resultLineRow(tokens, resultLine),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            // 底部留白避开悬浮按钮，移动端再加安全区（设计稿 list-pad）
            padding: EdgeInsets.fromLTRB(
              context.mxListPadX,
              6,
              context.mxListPadX,
              (context.isMobileLayout ? 96 : 80) + context.mxSafeBottom,
            ),
            itemCount: logs.length + (showFooter ? 1 : 0),
            itemBuilder: (BuildContext context, int index) {
              if (index >= logs.length) return const _LoadMoreFooter();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LogCard(log: logs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resultLineRow(MXTokens tokens, String text) {
    return Padding(
      // 与日志卡片左右对齐
      padding: EdgeInsets.fromLTRB(context.mxListPadX + 2, 8, context.mxListPadX + 2, 2),
      child: Text(text, style: TextStyle(fontSize: 12, color: tokens.faint)),
    );
  }

  /// 无匹配结果（对齐设计稿 noResult）
  Widget _noResult(MXTokens tokens) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "⌕",
            style: TextStyle(fontSize: 34, color: tokens.faint.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.noMatchLogs,
            style: TextStyle(fontSize: 14, color: tokens.faint),
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                store.filter.update((LogFilterState filter) => filter.clearAll());
                showMXToast(context, context.l10n.clearAllFilters);
              },
              child: Text(
                context.l10n.clearAllFiltersLink,
                style: TextStyle(fontSize: 13, color: tokens.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jumpButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundFabButton(
          tooltip: context.l10n.jumpTopTip,
          icon: Icons.arrow_upward,
          onTap: () => _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        ),
        const SizedBox(height: 6),
        _RoundFabButton(
          tooltip: context.l10n.jumpBottomTip,
          icon: Icons.arrow_downward,
          onTap: () => _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          ),
        ),
      ],
    );
  }
}

/// 分页加载 footer：复用导入 loading 的脉冲动画。
/// 同时兼作加载哨兵——被构建即说明滚动到了列表末尾，兜底触发下一页
/// （首页不满一屏、或快速拖拽跳过滚动阈值时监听可能漏触发）。
class _LoadMoreFooter extends StatefulWidget {
  const _LoadMoreFooter();

  @override
  State<_LoadMoreFooter> createState() => _LoadMoreFooterState();
}

class _LoadMoreFooterState extends State<_LoadMoreFooter> {
  @override
  void initState() {
    super.initState();
    // build 期间不能改状态，推迟到帧末
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) MXScope.of(context).logList.loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(child: MXPulseGrid()),
    );
  }
}

/// 嵌入模式无数据空态：空白页 + 「刷新日志」按钮。
/// 打开弹窗不自动解析（日志量大时耗时），解析完全由用户主动触发。
class _EmbedEmptyState extends MXConsumerWidget {
  const _EmbedEmptyState();

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final MXStore store = ref.store;
    final bool isDark = ref.watch(store.themeMode) == ThemeMode.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: Center(
            child: Padding
              (padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MXLogo(size: 48),
                  const SizedBox(height: 18),
                  Text(
                    context.l10n.embedEmptyTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.embedEmptyDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.7, color: tokens.muted),
                  ),
                  const SizedBox(height: 22),
                  _PrimaryActionButton(
                    icon: Icons.refresh,
                    label: context.l10n.refresh,
                    onTap: () => refreshDeviceLogs(context, store),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MXIconButton(
                tooltip: isDark ? context.l10n.themeToLight : context.l10n.themeToDark,
                icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                    size: 15),
                size: context.mxTopButtonSize,
                onTap: store.themeMode.toggle,
              ),
              const SizedBox(width: 7),
              MXIconButton(
                tooltip: context.l10n.languageTip,
                icon: const Icon(Icons.translate, size: 15),
                size: context.mxTopButtonSize,
                onTap: store.locale.toggle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 无数据空态：拖入或选择日志文件（对齐设计稿投放卡片）。
class _EmptyDropState extends MXConsumerWidget {
  const _EmptyDropState({required this.dragover});

  final bool dragover;

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final MXStore store = ref.store;
    final bool isDark = ref.watch(store.themeMode) == ThemeMode.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: _dropCard(context, store, tokens)),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MXIconButton(
                tooltip: isDark ? context.l10n.themeToLight : context.l10n.themeToDark,
                icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                    size: 15),
                size: context.mxTopButtonSize,
                onTap: store.themeMode.toggle,
              ),
              const SizedBox(width: 7),
              MXIconButton(
                tooltip: context.l10n.languageTip,
                icon: const Icon(Icons.translate, size: 15),
                size: context.mxTopButtonSize,
                onTap: store.locale.toggle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropCard(BuildContext context, MXStore store, MXTokens tokens) {
    return AnimatedScale(
      scale: dragover ? 1.01 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: dragover ? tokens.accent : tokens.border,
            radius: 18,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            // 移动端收窄内边距（设计稿 drop-card 34px 18px 30px）
            padding: context.isMobileLayout
                ? const EdgeInsets.fromLTRB(18, 34, 18, 30)
                : const EdgeInsets.fromLTRB(32, 52, 32, 40),
            decoration: BoxDecoration(
              color: dragover
                  ? Color.alphaBlend(tokens.accent.withValues(alpha: 0.07), tokens.panel)
                  : tokens.panel,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: tokens.panel2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Icon(Icons.article_outlined, size: 28, color: tokens.accent),
                ),
                const SizedBox(height: 18),
                Text(
                  context.l10n.dropTitle,
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: tokens.text),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.dropDesc,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.7, color: tokens.muted),
                ),
                const SizedBox(height: 22),
                // 宿主没注入选文件能力时只保留拖入路径，不渲染死按钮
                if (store.host.canPickFiles)
                  _PrimaryActionButton(
                    icon: Icons.folder_outlined,
                    label: context.l10n.pickFile,
                    onTap: () => pickAndImportLogFiles(context, store),
                  ),
                const SizedBox(height: 16),
                _KeyIvLink(
                  label: context.l10n.cryptoTip,
                  onTap: () => store.screen.show(MxScreen.landing),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空态主按钮（accent 底白字）：桌面「选择日志文件」/ 嵌入「刷新日志」共用。
class _PrimaryActionButton extends StatefulWidget {
  const _PrimaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering
                ? Color.alphaBlend(Colors.white.withValues(alpha: 0.1), tokens.accent)
                : tokens.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「修改解密 Key / IV」链接（回到配置页）。
class _KeyIvLink extends StatefulWidget {
  const _KeyIvLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_KeyIvLink> createState() => _KeyIvLinkState();
}

class _KeyIvLinkState extends State<_KeyIvLink> {
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
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 12.5,
            color: _hovering ? tokens.accent : tokens.faint,
            decoration: _hovering ? TextDecoration.underline : TextDecoration.none,
            decorationColor: tokens.accent,
          ),
        ),
      ),
    );
  }
}

/// 圆形悬浮按钮（回顶/回底、手机端刷新共用）。
class _RoundFabButton extends StatefulWidget {
  const _RoundFabButton({required this.tooltip, required this.icon, required this.onTap});

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_RoundFabButton> createState() => _RoundFabButtonState();
}

class _RoundFabButtonState extends State<_RoundFabButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    // 移动端加大到 44（设计稿 fab button），手指点得中
    final double size = context.mxFabSize;
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
              color: tokens.panel2,
              shape: BoxShape.circle,
              border: Border.all(color: _hovering ? tokens.faint : tokens.border),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), offset: Offset(0, 4), blurRadius: 14),
              ],
            ),
            child: Icon(
              widget.icon,
              size: size * 0.42,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 圆角虚线描边（Flutter 无原生 dashed border）。
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));

    const double dash = 6;
    const double gap = 5;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
