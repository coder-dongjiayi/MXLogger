import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/dialog/crypt_confirm_dialog.dart';

import 'support/test_store.dart';

void main() {
  // 记录弹框返回值供断言
  CryptConfirmResult? lastResult;
  bool dialogReturned = false;

  Future<MXStore> pump(WidgetTester tester) async {
    lastResult = null;
    dialogReturned = false;
    final MXStore store = await createTestStore(initialPrefs: const {
      "mx_crypt_key": "OLDKEY0000000000",
      "mx_crypt_iv": "OLDIV00000000000",
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
              builder: (BuildContext context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      lastResult = await showCryptConfirmDialog(context);
                      dialogReturned = true;
                    },
                    child: const Text("open"),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    return store;
  }

  testWidgets("弹框代入上次 Key/IV，修改并确认后保存；默认不清空", (WidgetTester tester) async {
    final MXStore store = await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    // 代入上次值
    expect(find.text("OLDKEY0000000000"), findsOneWidget);
    expect(find.text("OLDIV00000000000"), findsOneWidget);

    // 修改 KEY 后确认（「开始导入」按钮）
    await tester.enterText(find.byType(TextField).first, "NEWKEY1234567890");
    await tester.tap(find.text("开始导入"));
    await tester.pumpAndSettle();

    final CryptSettings crypt = store.crypt.value;
    expect(crypt.cryptKey, "NEWKEY1234567890");
    expect(crypt.cryptIv, "OLDIV00000000000");
    // 未勾选 → 不清空（合并）
    expect(lastResult?.clearExisting, isFalse);
  });

  testWidgets("勾选「清空已有数据」后确认，结果 clearExisting 为 true", (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    await tester.tap(find.text("导入前清空已有数据"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("开始导入"));
    await tester.pumpAndSettle();

    expect(lastResult?.clearExisting, isTrue);
  });

  testWidgets("可添加第二组 Key/IV，确认后按列表顺序保存并勾选", (WidgetTester tester) async {
    final MXStore store = await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    // 初始一组（迁移自旧配置），勾选框里是尝试序号 1
    expect(find.text("1"), findsOneWidget);

    await tester.tap(find.text("添加一组"));
    await tester.pumpAndSettle();
    expect(find.text("2"), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), "SECONDKEY0000000");
    await tester.enterText(find.byType(TextField).at(3), "SECONDIV00000000");
    await tester.tap(find.text("开始导入"));
    await tester.pumpAndSettle();

    final List<CryptEntry> entries = store.crypt.value.entries;
    expect(entries.length, 2);
    expect(entries[0].cryptKey, "OLDKEY0000000000");
    expect(entries[1].cryptKey, "SECONDKEY0000000");
    expect(entries[1].cryptIv, "SECONDIV00000000");
    // 顺序即解密尝试顺序
    expect(store.crypt.value.cryptPairs.map((MxCryptPair p) => p.key),
        ["OLDKEY0000000000", "SECONDKEY0000000"]);
  });

  testWidgets("取消勾选的组不参与解密，但配置仍保留", (WidgetTester tester) async {
    final MXStore store = await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    // 点勾选框（显示序号 1 的方块）取消勾选
    await tester.tap(find.text("1"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("开始导入"));
    await tester.pumpAndSettle();

    expect(store.crypt.value.entries.single.enabled, isFalse);
    expect(store.crypt.value.cryptPairs, isEmpty);
  });

  testWidgets("可以删空所有组，确认后按未加密解析", (WidgetTester tester) async {
    final MXStore store = await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    // 唯一一组也能删（删除按钮即行尾的 X）
    await tester.tap(find.byTooltip("移除这一组"));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text("未配置解密参数，按未加密的日志解析；需要解密请点左侧按钮添加"), findsOneWidget);

    await tester.tap(find.text("开始导入"));
    await tester.pumpAndSettle();

    expect(store.crypt.value.entries, isEmpty);
    expect(store.crypt.value.cryptPairs, isEmpty);
  });

  testWidgets("取消不修改 Key/IV，返回 null", (WidgetTester tester) async {
    final MXStore store = await pump(tester);
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, "SHOULDNOTSAVE00");
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    expect(store.crypt.value.cryptKey, "OLDKEY0000000000");
    expect(dialogReturned, isTrue);
    expect(lastResult, isNull);
  });
}
