import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

import 'support/test_store.dart';

/// 可控假数据层：数据页渲染所需的查询 + 清库打点。
class _FakeHomeRepository extends EmptyRepository {
  bool cleared = false;

  @override
  Future<HeaderInfo> fetchHeaderInfo() async => cleared
      ? const HeaderInfo()
      : const HeaderInfo(
          total: 5,
          minUs: 1700000000000000,
          maxUs: 1700000600000000,
          fileName: "a.mx",
        );

  @override
  Future<Map<int, int>> fetchLevelCounts() async => cleared ? {} : {0: 2, 1: 3};

  @override
  Future<void> clearAll() async => cleared = true;
}

/// 清除数据端到端：右上角按钮 → 确认弹框 → 清库并回到首次引导页。
void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.platformDispatcher.views.first.physicalSize = const Size(1280, 1400);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets("清除数据：弹框取消不清库，确认后回到引导页并复位进入标记", (WidgetTester tester) async {
    final _FakeHomeRepository repo = _FakeHomeRepository();
    // 已进入过数据页的用户
    final MXStore store = await createTestStore(
      repository: repo,
      initialPrefs: const {"mx_entered": true},
    );

    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 数据页就绪，右上角有清除数据按钮
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // 打开弹框：文案齐备
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text("清空数据"), findsOneWidget);
    expect(find.text("您确认要清空数据么？"), findsOneWidget);

    // 取消：不清库，仍在数据页
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();
    expect(repo.cleared, isFalse);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // 确认清空：清库 + 回到首次引导页（三步向导第一步）+ 进入标记复位
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text("清空"));
    await tester.pumpAndSettle();

    expect(repo.cleared, isTrue);
    expect(find.text("下一步"), findsOneWidget);
    expect(store.host.prefs.getBool("mx_entered"), isFalse);

    // 走完 toast 的 1.6s 定时器，避免测试结束时残留 pending timer
    await tester.pump(const Duration(seconds: 2));
  });
}
