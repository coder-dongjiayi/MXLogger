import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_toolbar.dart';

import 'support/test_store.dart';

/// 固定候选的假数据层，隔离数据库。
class _FakeRepo extends EmptyRepository {
  @override
  Future<List<String>> fetchTagOptions() async => ["auth", "network", "netcore"];

  @override
  Future<List<String>> fetchNameOptions() async => ["Auth", "NetworkClient"];
}

void main() {
  Future<MXStore> pumpToolbar(WidgetTester tester) async {
    final MXStore store = await createTestStore(repository: _FakeRepo());
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const Scaffold(body: DataToolbar()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets("输入 # 列出全部 tag，继续输入按匹配过滤", (WidgetTester tester) async {
    await pumpToolbar(tester);

    // # 打开候选，列出全部 tag
    await tester.enterText(find.byType(TextField), "#");
    await tester.pumpAndSettle();
    expect(find.text("auth"), findsOneWidget);
    expect(find.text("network"), findsOneWidget);
    expect(find.text("netcore"), findsOneWidget);

    // 继续输入 net：只剩匹配项
    await tester.enterText(find.byType(TextField), "#net");
    await tester.pumpAndSettle();
    expect(find.text("auth"), findsNothing);
    expect(find.text("network"), findsOneWidget);
    expect(find.text("netcore"), findsOneWidget);
  });

  testWidgets("上下键导航 + 回车选中，追加为多选 tag chip 显示在框内", (WidgetTester tester) async {
    final MXStore store = await pumpToolbar(tester);

    await tester.enterText(find.byType(TextField), "#");
    await tester.pumpAndSettle();
    // 默认高亮首项(auth)，下移一格到 network，回车选中
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(store.filter.value.tags, ["network"]);
    // 选中后输入框清空、浮层关闭
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? "",
      isEmpty,
    );
    // 框内出现 #network chip
    expect(find.text("#network"), findsOneWidget);

    // 再选一个 tag：多选累加
    await tester.enterText(find.byType(TextField), "#auth");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(store.filter.value.tags, ["network", "auth"]);
    expect(find.text("#auth"), findsOneWidget);
  });

  testWidgets("输入框为空时按退格删除最后一个 chip（先删 name 再删 tag）", (WidgetTester tester) async {
    final MXStore store = await pumpToolbar(tester);

    // 选一个 tag + 一个 name
    await tester.enterText(find.byType(TextField), "#network");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "@NetworkClient");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(store.filter.value.tags, ["network"]);
    expect(store.filter.value.names, ["NetworkClient"]);

    // 输入框此时为空，退格先删 name
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(store.filter.value.names, isEmpty);
    expect(store.filter.value.tags, ["network"]);

    // 再退格删 tag
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(store.filter.value.tags, isEmpty);
  });

  testWidgets("输入框有文字时退格不删 chip（正常删字）", (WidgetTester tester) async {
    final MXStore store = await pumpToolbar(tester);
    await tester.enterText(find.byType(TextField), "#network");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(store.filter.value.tags, ["network"]);

    // 输入普通文字后退格，只删字不动 chip
    await tester.enterText(find.byType(TextField), "ab");
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(store.filter.value.tags, ["network"]);
  });

  testWidgets("点击候选项追加 name，多选去重", (WidgetTester tester) async {
    final MXStore store = await pumpToolbar(tester);

    await tester.enterText(find.byType(TextField), "@Net");
    await tester.pumpAndSettle();
    await tester.tap(find.text("NetworkClient"));
    await tester.pumpAndSettle();
    expect(store.filter.value.names, ["NetworkClient"]);
    expect(find.text("@NetworkClient"), findsOneWidget);

    // 重复选中同一项不产生重复
    await tester.enterText(find.byType(TextField), "@Net");
    await tester.pumpAndSettle();
    await tester.tap(find.text("NetworkClient"));
    await tester.pumpAndSettle();
    expect(store.filter.value.names, ["NetworkClient"]);
  });

  testWidgets("普通关键词不进入联想，正常防抖生效", (WidgetTester tester) async {
    final MXStore store = await pumpToolbar(tester);

    await tester.enterText(find.byType(TextField), "error");
    await tester.pump(const Duration(milliseconds: 250));
    expect(store.filter.value.keyword, "error");
    // 无候选浮层
    expect(find.text("选择 Tag · ↑↓ 切换 · 回车选中"), findsNothing);
  });
}
