import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/embed/mx_analyzer.dart';
import 'package:mxlogger_analyzer_lib/src/screens/landing/landing_screen.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

/// 生成 README 用的界面截图（产物落在 `mxlogger_analyzer_lib/screenshots/`）：
///
/// ```bash
/// flutter test integration_test/generate_screenshots_test.dart -d macos \
///     --dart-define=OUT_DIR=$PWD/mxlogger_analyzer_lib/screenshots
/// ```
///
/// 跑在**真实 macOS 应用**里而不是 `flutter test`：headless 测试环境只有占位字体，
/// 日志正文/Tag/JSON 树这些指定了等宽回退链的文本会整片渲染成方框
/// （fontFamilyFallback 会让主字体退化成测试占位字体），只有真机进程才拿得到
/// 系统字体。尺寸、假数据与主题仍全部由代码固定，换版本重跑一次即可整套更新。
///
/// 沙盒应用不一定写得进仓库目录，写失败时退回应用支持目录并打印路径。
const String _outputDir =
    String.fromEnvironment("OUT_DIR", defaultValue: "screenshots");

/// 截图倍率（逻辑尺寸的 1.5 倍像素：README 里缩放显示够清晰，体积也不至于失控）
const double _pixelRatio = 1.5;

/// 假数据层：覆盖数据页需要的全部查询，不触达 sqlite。
class _FakeRepository extends HomeRepository {
  _FakeRepository({required this.logs, required this.header})
      : super(_noDatabase);

  static Future<AnalyzerDatabase> _noDatabase() =>
      throw UnimplementedError("截图工具不使用数据库");

  final List<LogModel> logs;
  final HeaderInfo header;

  @override
  Future<HeaderInfo> fetchHeaderInfo() async => header;

  @override
  Future<Map<int, int>> fetchLevelCounts() async {
    final Map<int, int> counts = <int, int>{0: 5231, 1: 12480, 2: 864, 3: 173, 4: 12};
    return counts;
  }

  @override
  Future<List<LogModel>> fetchLogs(LogFilterState filter,
      {int? limit, int? offset}) async {
    if (offset != null && offset >= logs.length) return const <LogModel>[];
    return logs;
  }

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => 18760;

  @override
  Future<List<String>> fetchTagOptions() async =>
      const ["network", "POST", "GET", "200", "404", "login", "flutter", "db"];

  @override
  Future<List<String>> fetchNameOptions() async =>
      const ["network", "login", "flutter", "database", "batch"];
}

/// 覆盖 DEBUG–FATAL 的样例日志（含 JSON 正文、多 tag、堆栈文本），
/// 内容与 `lib/main_package.dart` 写入的样例一致。
List<LogModel> _sampleLogs() {
  const int base = 1755993600000000; // 2025-08-24 08:00:00 UTC
  const String fileHeader =
      '{"model":"iPhone 16 Pro","systemVersion":"18.5","brand":"Apple",'
      '"appVersion":"2.0.0","buildNumber":"210","isPhysicalDevice":true,'
      '"identifier":"iPhone17,1","locale":"zh_CN"}';
  int index = 0;
  LogModel make({
    required int level,
    required String name,
    required String tag,
    required String msg,
    int seconds = 3,
  }) {
    index = index + 1;
    return LogModel(
      id: index,
      name: name,
      tag: tag,
      msg: msg,
      level: level,
      threadId: 1,
      isMainThread: 1,
      timestamp: base + index * seconds * 1000000 + index * 137000,
      fileHeader: fileHeader,
    );
  }

  return <LogModel>[
    make(
      level: 1,
      name: "network",
      tag: "network,POST,200",
      msg: '{"uri":"https://api.mxlogger.dev/v2/user/login","method":"POST",'
          '"statusCode":200,"connectTimeout":15000,'
          '"headers":{"content-type":"application/json; charset=utf-8",'
          '"accept-language":"zh","service-name":"app","version":"2.2.0"},'
          '"request":{"mobile":"188****6666","channel":"appstore"},'
          '"response":{"code":0,"msg":"操作成功","data":{"userId":71349214,'
          '"nickname":"张三","vip":true}}}',
    ),
    make(
      level: 0,
      name: "login",
      tag: "login,service",
      msg: "开始校验本地 token，缓存命中，剩余有效期 1723s",
    ),
    make(
      level: 2,
      name: "network",
      tag: "network,GET,404",
      msg: '{"uri":"https://api.mxlogger.dev/v2/course/detail","method":"GET",'
          '"statusCode":404,"response":{"code":404,"msg":"not found"}}',
    ),
    make(
      level: 3,
      name: "flutter",
      tag: "flutter,crash",
      msg: """The following _TypeError was thrown building LogPage(dirty, state: _LogPageState#0b85e):
type 'Null' is not a subtype of type 'String'

#0      _LogPageState.build (package:example/log_page.dart:45:12)
#1      StatefulElement.build (package:flutter/src/widgets/framework.dart:4919:27)
#2      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:4806:15)""",
    ),
    make(
      level: 4,
      name: "database",
      tag: "db,fatal",
      msg: "数据库连接丢失，业务不可用：SqliteException(11): database disk image is malformed",
    ),
    make(
      level: 0,
      name: "batch",
      tag: "batch,level0",
      msg: "批量日志 #128 已落盘，mmap 剩余可写空间 3.2 MB",
    ),
  ];
}

HeaderInfo _sampleHeader() => HeaderInfo(
      total: 18760,
      minUs: 1755993600000000,
      maxUs: 1756036800000000,
      fileName: "2025-08-24.mx",
      header: HeaderInfo.parseHeader(_sampleLogs().first.fileHeader),
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 截图落盘目录：优先仓库目录（--dart-define=OUT_DIR），
  /// 沙盒禁止写入时退回应用支持目录
  late Directory outputDir;

  setUpAll(() async {
    Directory candidate = Directory(_outputDir);
    try {
      candidate.createSync(recursive: true);
      File("${candidate.path}/.probe").writeAsStringSync("ok");
      File("${candidate.path}/.probe").deleteSync();
    } catch (_) {
      candidate =
          Directory("${(await getApplicationSupportDirectory()).path}/screenshots");
      candidate.createSync(recursive: true);
    }
    outputDir = candidate;
    debugPrint("截图输出目录：${outputDir.path}");
  });

  /// 固定逻辑尺寸与安全区，与真实窗口大小无关
  void useScreen(WidgetTester tester, Size size,
      {FakeViewPadding padding = FakeViewPadding.zero}) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1.0
      ..padding = padding
      ..viewPadding = padding;
    addTearDown(tester.view.reset);
  }

  /// 页面里可能存在永不停止的动画（加载指示器），pumpAndSettle 会超时，
  /// 超时后退化为固定帧数推进，保证仍能截到稳定画面。
  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
    } catch (_) {
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
  }

  final GlobalKey shotKey = GlobalKey();

  Future<MXStore> pump(
    WidgetTester tester, {
    required Widget home,
    ThemeMode themeMode = ThemeMode.dark,
    bool entered = true,
    HomeRepository? repository,
    String? diskcachePath,
  }) async {
    final MXStore store = MXStore(
      host: MXHost(
        prefs: MXMemoryPrefs(<String, Object>{
          "mx_entered": entered,
          "mxlogger-theme": themeMode == ThemeMode.light ? "light" : "dark",
        }),
      ),
      repository: repository ??
          _FakeRepository(logs: _sampleLogs(), header: _sampleHeader()),
      diskcachePath: diskcachePath,
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: MXScope(
        store: store,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: themeMode == ThemeMode.light ? MXTheme.light() : MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: home,
        ),
      ),
    ));
    await settle(tester);
    return store;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final RenderRepaintBoundary boundary =
        tester.renderObject(find.byKey(shotKey));
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: _pixelRatio);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final File file = File("${outputDir.path}/$name.png");
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      stdout.writeln("已生成 ${file.path} (${bytes.lengthInBytes ~/ 1024} KB)");
    });
  }

  testWidgets("桌面数据页", (WidgetTester tester) async {
    useScreen(tester, const Size(1280, 860));
    await pump(tester, home: const MainScreen());
    await shoot(tester, "desktop_dark");
  });

  testWidgets("首次引导向导", (WidgetTester tester) async {
    useScreen(tester, const Size(1280, 860));
    await pump(tester,
        home: const Scaffold(body: LandingScreen()), entered: false);
    await shoot(tester, "desktop_wizard");
  });

  testWidgets("桌面：单条日志全屏详情", (WidgetTester tester) async {
    useScreen(tester, const Size(1280, 860));
    await pump(tester, home: const MainScreen());
    await tester.tap(find.byIcon(Icons.fullscreen).first);
    await settle(tester);
    await shoot(tester, "desktop_detail");
  });

  testWidgets("手机：嵌入宿主 app 的悬浮球 + 底部弹窗", (WidgetTester tester) async {
    useScreen(tester, const Size(390, 844),
        padding: const FakeViewPadding(top: 47, bottom: 34));
    final MXStore store = MXStore(
      host: MXHost(
        prefs: MXMemoryPrefs(const <String, Object>{
          "mx_entered": true,
          "mxlogger-theme": "dark",
          "mxlogger-locale": "zh",
        }),
      ),
      repository: _FakeRepository(logs: _sampleLogs(), header: _sampleHeader()),
      diskcachePath: "/tmp/flutter.mxlogger",
    );
    addTearDown(store.dispose);

    // 与 MXAnalyzer.showDebug 的真实结构一致：宿主 app 的界面之上盖一层
    // 占屏幕 85% 的底部弹窗（圆角 + 移除顶部安全区）
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(builder: (BuildContext context) {
          final double height = MediaQuery.of(context).size.height;
          return Scaffold(
            appBar: AppBar(title: const Text("MXAnalyzer 嵌入调试")),
            // 宿主 app 的样子对齐 lib/main_package.dart 的调试入口
            body: Stack(children: <Widget>[
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text("/var/mobile/.../flutter.mxlogger",
                          style: TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: () {},
                          child: const Text("写入日志（各等级样例）")),
                      ElevatedButton(
                          onPressed: () {}, child: const Text("批量写入 200 条")),
                      ElevatedButton(
                          onPressed: () {},
                          child: const Text("显示调试器（悬浮球）")),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: height * 0.85,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: MXAnalyzerEmbedApp(store: store),
                  ),
                ),
              ),
            ]),
          );
        }),
      ),
    ));
    await settle(tester);
    await shoot(tester, "mobile_embed");
  });
}
