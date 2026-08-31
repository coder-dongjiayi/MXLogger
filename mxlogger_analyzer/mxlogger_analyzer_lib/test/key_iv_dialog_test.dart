import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/dialog/key_iv_dialog.dart';

import 'support/test_store.dart';

/// header 钥匙按钮的解密 KEY / IV 弹框：已保存的组掩码只读，可增、可删、可拖动排序。
void main() {
  /// 两组已保存的参数（顺序即解密尝试顺序）
  Future<MXStore> pump(WidgetTester tester) async {
    final MXStore store = await createTestStore(initialPrefs: const {
      "mx_crypt_entries": '[{"key":"KEY1000000000000","iv":"IV10000000000000","enabled":true},'
          '{"key":"KEY2000000000000","iv":"IV20000000000000","enabled":true}]',
    });
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: ElevatedButton(
                  onPressed: () => showKeyIvDialog(context),
                  child: const Text("open"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    return store;
  }

  List<String> keysOf(MXStore store) =>
      store.crypt.value.entries.map((CryptEntry entry) => entry.cryptKey).toList();

  testWidgets("弹框里已保存的组掩码显示且不可编辑", (WidgetTester tester) async {
    await pump(tester);

    // 不露明文，只显示前 2 位 + ****** + 后 2 位
    expect(find.text("KEY1000000000000"), findsNothing);
    expect(find.text("KEY2000000000000"), findsNothing);
    expect(find.text("KE******00"), findsNWidgets(2));
    expect(find.text("IV******00"), findsNWidgets(2));
    // 只读：没有可输入的文本框
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("可以增加一组、删除一组，应用后与列表一致；新增行可输入", (WidgetTester tester) async {
    final MXStore store = await pump(tester);

    // 删掉第一组
    await tester.tap(find.byTooltip("移除这一组").first);
    await tester.pumpAndSettle();

    // 再加一组填在末尾：只有新增行有 KEY / IV 两个输入框
    await tester.tap(find.text("添加一组"));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).at(0), "KEY3000000000000");
    await tester.enterText(find.byType(TextField).at(1), "IV30000000000000");

    await tester.tap(find.text("应用"));
    await tester.pumpAndSettle();

    expect(keysOf(store), ["KEY2000000000000", "KEY3000000000000"]);
    // 参数已更新的 toast（等 1.6s 自动消失，否则收尾会报 pending timer）
    expect(find.text("Key/IV 已更新"), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("拖动把手排序，应用后解密尝试顺序随之调整", (WidgetTester tester) async {
    final MXStore store = await pump(tester);

    final Finder handles = find.byTooltip("拖动调整尝试顺序");
    expect(handles, findsNWidgets(2));
    final Offset first = tester.getCenter(handles.at(0));
    final Offset second = tester.getCenter(handles.at(1));

    // 把第一组拖到第二组下面
    final TestGesture gesture = await tester.startGesture(first);
    await tester.pump(const Duration(milliseconds: 120));
    final double step = (second.dy - first.dy) / 4;
    for (int i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text("应用"));
    await tester.pumpAndSettle();

    // 序号（即尝试顺序）跟着走：原来的第二组现在排在最前
    expect(keysOf(store), ["KEY2000000000000", "KEY1000000000000"]);
    expect(store.crypt.value.cryptPairs.map((MxCryptPair pair) => pair.key),
        ["KEY2000000000000", "KEY1000000000000"]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("取消不改动已保存的参数", (WidgetTester tester) async {
    final MXStore store = await pump(tester);

    // 已保存的组只读，改动只能来自新增行；取消后新增的组不落库
    await tester.tap(find.text("添加一组"));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, "SHOULDNOTSAVE000");
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    expect(keysOf(store), ["KEY1000000000000", "KEY2000000000000"]);
    expect(find.text("Key/IV 已更新"), findsNothing);
  });
}
