import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

/// 嵌入式调试入口：在宿主 app 内显示可拖动悬浮球，
/// 点击弹出完整的 2.0 分析器（自带主题/多语言/导航，不依赖宿主配置）。
///
/// 用法（分享实现与解密参数都由主 app 注入）：
/// ```dart
/// MXAnalyzer.showDebug(navigatorKey.currentState!.overlay!,
///     diskcachePath: logger.diskcachePath,
///     // 日志未加密传空数组；换过密钥可传多组，解析时逐条按顺序尝试
///     cryptPairs: [MxCryptPair(key: logger.cryptKey!, iv: logger.iv!)],
///     onShare: (MXShareRequest request) async {
///       // 主 app 自行接入 share_plus 等插件；返回 false 降级复制剪贴板
///       ...
///     });
/// MXAnalyzer.dismiss();
/// ```
class MXAnalyzer {
  MXAnalyzer._();

  static OverlayEntry? _entry;
  static MXStore? _store;
  static bool _ballVisible = true;
  static Offset _offset = Offset.zero;
  static String? _databasePath;
  static MXPrefs? _prefs;
  static MXShareHandler? _share;
  static const double _size = 64;

  /// 可选预配置：
  /// [databasePath] 指定 sqlite 数据库存放目录，
  /// 不调用则默认使用 getApplicationSupportDirectory()。
  /// [prefs] 注入设置（主题/语言/解密参数）的持久化实现；
  /// 不注入则只存内存——KEY/IV 每次由 [showDebug] 传入，本就无需落盘，
  /// 分析器也因此不必依赖 shared_preferences 之类的存储插件。
  static void initialize({
    String? databasePath,
    MXPrefs? prefs,
  }) {
    _databasePath = databasePath;
    if (prefs != null) _prefs = prefs;
  }

  /// 显示悬浮球。重复调用（悬浮球已存在时）直接忽略。
  ///
  /// [diskcachePath]：MXLogger 的日志目录。打开弹窗**不会**自动解析，
  /// 由用户点分析器里的「刷新」按钮扫描其中的 .mx/.log/.txt/.json；
  /// 每次刷新都清空数据库重新解析，所见即本次扫描的全量结果。
  /// [cryptPairs]：日志的 AES 解密参数，必传。日志未加密传空数组；
  /// 同一个日志文件里的记录由不同 Key/IV 加密（写入端换过密钥）时可传多组，
  /// 解析时逐条按给定顺序尝试，第一组解不开就换下一组。
  /// 传入的组会置于分析器设置表首并勾选（已存在的同一组只确保勾选），
  /// 用户在分析器里自己加的组原样保留，后续「重新解析」弹窗会自动代入。
  /// [onShare]：分享实现，必传。分析器内核不依赖分享插件，由主 app 决定
  /// 怎么分享（如自行接入 share_plus 后转调，见 [MXShareHandler]）；
  /// 不想支持系统分享时返回 false，分析器会降级为复制到剪贴板。
  static Future<void> showDebug(
    OverlayState overlayState, {
    required String diskcachePath,
    required List<MxCryptPair> cryptPairs,
    required MXShareHandler onShare,
    String? databasePath,
  }) async {
    if (_entry != null) return;
    if (databasePath != null) _databasePath = databasePath;
    _share = onShare;
    final Size screen = MediaQuery.of(overlayState.context).size;

    final MXStore store = await _ensureStore(diskcachePath);
    // 嵌入模式跳过首次引导向导，直接进数据页
    store.screen.enter();
    store.crypt.upsertAll(cryptPairs);

    _offset = Offset((screen.width - _size) / 2, (screen.height - _size) / 2);
    _ballVisible = true;

    final OverlayEntry entry = OverlayEntry(builder: (BuildContext context) {
      return Positioned(
        left: _offset.dx,
        top: _offset.dy,
        child: GestureDetector(
          onPanUpdate: (DragUpdateDetails details) {
            final Offset next = _offset + details.delta;
            final Size size = MediaQuery.of(context).size;
            if (next.dx >= 0 &&
                next.dy >= 0 &&
                next.dx + _size <= size.width &&
                next.dy + _size <= size.height) {
              _offset = next;
              _entry?.markNeedsBuild();
            }
          },
          onDoubleTap: dismiss,
          onTap: () async {
            _ballVisible = false;
            _entry?.markNeedsBuild();
            await _showSheet(context, store);
            _ballVisible = true;
            _entry?.markNeedsBuild();
          },
          child: Visibility(
            visible: _ballVisible,
            child: const _FloatingLogo(size: _size),
          ),
        ),
      );
    });
    _entry = entry;
    overlayState.insert(entry);
  }

  /// 移除悬浮球并释放数据库连接。
  static void dismiss() {
    _entry?.remove();
    _entry = null;
    _store?.dispose();
    _store = null;
  }

  static Future<MXStore> _ensureStore(String diskcachePath) async {
    final MXStore? existing = _store;
    if (existing != null) return existing;
    // 默认内存 prefs 进程内复用：悬浮球关了再开，主题/语言/临时加的组不丢
    final MXPrefs prefs = _prefs ??= MXMemoryPrefs();
    final MXStore store = MXStore(
      // 嵌入模式不注入选文件/拖入能力：日志来源固定为宿主日志目录；
      // 分享能力由主 app 经 showDebug(onShare:) 注入
      host: MXHost(prefs: prefs, share: _share),
      databasePath: _databasePath,
      // 非空即嵌入模式：日志来源固定为本机目录，由用户点「刷新」触发解析
      diskcachePath: diskcachePath,
    );
    // 不清库：上次解析的结果留在 sqlite 里，重启 app 打开仍能直接看，
    // 要拿最新日志由用户点「刷新」（刷新本身会清库重新全量解析）
    _store = store;
    return store;
  }

  static Future<void> _showSheet(BuildContext context, MXStore store) async {
    // 打开不做任何解析：已入库的日志直接展示，无数据则是带「刷新」按钮的空页，
    // 解析由用户主动触发（日志量大时解析耗时，不该卡在打开弹窗上）
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            // 弹窗顶部在屏幕 15% 处，不需要避让状态栏；底部贴屏幕边缘，
            // 保留底部安全区供列表留白/悬浮按钮/弹窗底栏使用
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: MXAnalyzerEmbedApp(store: store),
            ),
          ),
        );
      },
    );
  }
}

/// 悬浮入口：直接用品牌 logo 的圆角方块（不再套一层圆形底），
/// 阴影贴合 logo 内部方框（logo 视口 48 单位，方框区 3..45、圆角 11）。
class _FloatingLogo extends StatelessWidget {
  const _FloatingLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double unit = size / 48;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 3 * unit,
            top: 3 * unit,
            width: 42 * unit,
            height: 42 * unit,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11 * unit),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x59000000), offset: Offset(0, 3), blurRadius: 10),
                ],
              ),
            ),
          ),
          // 宿主 app 拿不到分析器主题，固定用深色 tokens（悬浮在任意界面上都清晰）
          Positioned.fill(
            child: CustomPaint(painter: MXLogoPainter(MXTokens.dark)),
          ),
        ],
      ),
    );
  }
}

/// 弹窗内容：自带 Navigator / 主题 / 多语言的嵌套 MaterialApp，
/// 分析器内部的 dialog、toast、l10n 全部自给自足，不要求宿主 app
/// 配置 AppLocalizations 或 MXScope。
class MXAnalyzerEmbedApp extends StatelessWidget {
  const MXAnalyzerEmbedApp({super.key, required this.store});

  final MXStore store;

  @override
  Widget build(BuildContext context) {
    return MXScope(
      store: store,
      child: MXConsumer(builder: (BuildContext context, MXRef ref) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MXTheme.light(),
          darkTheme: MXTheme.dark(),
          themeMode: ref.watch(store.themeMode),
          locale: ref.watch(store.locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainScreen(),
        );
      }),
    );
  }
}
