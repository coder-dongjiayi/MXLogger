import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/landing/landing_screen.dart';

import 'support/test_store.dart';

/// 首次使用三步向导：文件 → Key/IV → 导入，含失败回退。
void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 向导卡片较高，放大视口保证按钮可命中
    binding.platformDispatcher.views.first.physicalSize = const Size(1280, 1400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  /// 渲染向导；[paths] 非空表示已选好文件
  Future<MXStore> pumpWizard(WidgetTester tester,
      {List<String> paths = const []}) async {
    final MXStore store = await createTestStore();
    if (paths.isNotEmpty) store.wizardPaths.value = paths;
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const Scaffold(body: LandingScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets("第一步：未选文件时「下一步」不可用，选中后展示文件名", (WidgetTester tester) async {
    await pumpWizard(tester);

    // 第一步元素齐备：标题 + 可点击选择文件的图标 + 下一步
    expect(find.text("选择日志文件开始"), findsOneWidget);
    expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
    expect(find.text("下一步"), findsOneWidget);

    // 未选文件时点「下一步」不进入第二步
    await tester.tap(find.text("下一步"));
    await tester.pumpAndSettle();
    expect(find.text("开始导入"), findsNothing);
  });

  testWidgets("选中文件后：下一步 → Key/IV 页（转场）→ 上一步返回", (WidgetTester tester) async {
    await pumpWizard(tester, paths: ["/tmp/a.mx", "/tmp/b.mx"]);

    expect(find.text("已选择 2 个文件"), findsOneWidget);
    expect(find.text("a.mx"), findsOneWidget);

    await tester.tap(find.text("下一步"));
    await tester.pumpAndSettle();

    // 第二步：KEY/IV + 开始导入
    expect(find.text("KEY"), findsOneWidget);
    expect(find.text("IV"), findsOneWidget);
    expect(find.text("开始导入"), findsOneWidget);
    expect(find.text("下一步"), findsNothing);

    // 上一步回到文件页
    await tester.tap(find.text("← 上一步"));
    await tester.pumpAndSettle();
    expect(find.text("下一步"), findsOneWidget);
  });

  testWidgets("已选文件可逐个移除，全部移除后「下一步」重新禁用", (WidgetTester tester) async {
    await pumpWizard(tester, paths: ["/tmp/a.mx", "/tmp/b.mx"]);

    expect(find.text("已选择 2 个文件"), findsOneWidget);
    // 每个 chip 一个移除按钮
    expect(find.byIcon(Icons.close), findsNWidgets(2));

    // 移除第一个：剩一个文件
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text("已选择 1 个文件"), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // 移除最后一个：回到未选状态，chip 区消失
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.textContaining("已选择"), findsNothing);

    // 未选文件时点「下一步」不进入第二步
    await tester.tap(find.text("下一步"));
    await tester.pumpAndSettle();
    expect(find.text("开始导入"), findsNothing);
  });

  testWidgets("开始导入：选择跨步骤保活，读取失败回退第一步", (WidgetTester tester) async {
    final MXStore store = await pumpWizard(tester);

    // 运行时写入选择（生产路径），验证切步骤后选择不丢
    store.wizardPaths.value = ["/tmp/not_exist_mxlogger.mx"];
    await tester.pumpAndSettle();
    expect(find.text("已选择 1 个文件"), findsOneWidget);

    await tester.tap(find.text("下一步"));
    await tester.pumpAndSettle();
    // 第一步组件已销毁，选择仍在（第二步的文件数提示）
    expect(find.text("已选择 1 个文件"), findsOneWidget);

    await tester.tap(find.text("开始导入"));
    // 文件长度读取是真实 IO，需在 runAsync 中等待其完成
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    // 读取失败（文件不存在）→ 回退到第一步，证明导入确实被触发
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("下一步"), findsOneWidget);
    expect(find.text("开始导入"), findsNothing);
  });

  testWidgets("导入 success 的过渡帧停留在 loading，不闪回第一步（回归闪现 bug）",
      (WidgetTester tester) async {
    final MXStore store = await pumpWizard(tester);

    // 直接注入运行态复现导入第三步（loading 动画为无限循环，只能定时 pump）
    store.importer.value = const ImportState(
      status: ImportStatus.running,
      step: ImportStep.indexing,
      percent: 90,
      fileLabel: "a.mx (1.0 KB)",
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("下一步"), findsNothing);

    // 单独渲染 LandingScreen（无 MainScreen 消费复位），success 应保持 loading 视图
    store.importer.value = const ImportState(
      status: ImportStatus.success,
      step: ImportStep.done,
      percent: 100,
      fileLabel: "a.mx (1.0 KB)",
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("下一步"), findsNothing);
    expect(find.text("开始导入"), findsNothing);
  });
}
