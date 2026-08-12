import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/screen_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

import 'support/test_store.dart';

/// MainScreen 统一消费导入结果：失败弹 toast 并把导入态复位。
/// 复位发生在导入态监听回调内部（回写同一状态），回归「重入通知」问题。
void main() {
  Future<MXStore> pumpMain(WidgetTester tester) async {
    final MXStore store = await createTestStore(initialPrefs: const {"mx_entered": true});
    await tester.pumpWidget(MXScope(
      store: store,
      child: MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("zh"),
        home: const MainScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets("读取失败：toast 提示并复位导入态", (WidgetTester tester) async {
    final MXStore store = await pumpMain(tester);

    store.importer.value = const ImportState(
      status: ImportStatus.failure,
      error: ImportError.readFailed,
    );
    await tester.pump();

    expect(find.text("文件读取失败，请重试"), findsOneWidget);
    // 监听回调内的复位生效（未因重入通知而抛错）
    expect(store.importer.value.status, ImportStatus.idle);

    // 走完 toast 定时器，避免残留 pending timer
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("解析失败：提示格式/Key 有误", (WidgetTester tester) async {
    final MXStore store = await pumpMain(tester);

    store.importer.value = const ImportState(
      status: ImportStatus.failure,
      error: ImportError.parseFailed,
    );
    await tester.pump();

    expect(find.text("解析失败（格式或 Key/IV 有误）"), findsOneWidget);
    expect(store.importer.value.status, ImportStatus.idle);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("落地页导入成功：记录进入标记并切到数据页", (WidgetTester tester) async {
    final MXStore store = await createTestStore();
    expect(store.screen.value, MxScreen.landing);

    await tester.pumpWidget(MXScope(
      store: store,
      child: MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("zh"),
        home: const MainScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    store.importer.value = const ImportState(
      status: ImportStatus.success,
      step: ImportStep.done,
      percent: 100,
    );
    await tester.pumpAndSettle();

    expect(store.screen.value, MxScreen.data);
    expect(store.host.prefs.getBool("mx_entered"), isTrue);
    // 切页帧之后才复位导入态
    expect(store.importer.value.status, ImportStatus.idle);
  });
}
