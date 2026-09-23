import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/highlight_text.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/json_tree.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_detail_dialog.dart';

import 'support/test_store.dart';

/// 全屏详情弹窗的正文内搜索：计数、上一处/下一处循环、滚动定位、Esc 先清搜索，
/// 以及 JSON 树按渲染顺序计数并自动展开含命中的折叠节点。
void main() {
  group("命中计数", () {
    test("纯文本忽略大小写、不重叠", () {
      expect(mxCountMatches("Needle needle NEEDLE", "needle"), 3);
      expect(mxCountMatches("aaaa", "aa"), 2);
      expect(mxCountMatches("abc", ""), 0);
      expect(mxCountMatches("abc", "zz"), 0);
    });

    test("JSON 按渲染顺序：key 先于值，数字参与，布尔不参与", () {
      const Map<String, Object?> json = {
        "needle": "a needle",
        "list": ["needle", 1, true],
        "n": 11,
      };
      expect(mxJsonMatchCount(json, "needle"), 3);
      expect(mxJsonMatchCount(json, "1"), 3); // 数字 1 与 11 内的两处
      expect(mxJsonMatchCount(json, "true"), 0);
    });
  });

  Widget wrap(MXStore store, Widget child) {
    return MXScope(
      store: store,
      child: MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("zh"),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets("JsonTree：当前命中落在折叠节点内时自动展开", (WidgetTester tester) async {
    final MXStore store = await createTestStore();
    const Map<String, Object?> json = {
      "outer": {"inner": {"deepKey": "deepValue"}},
    };
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(wrap(
      store,
      const SingleChildScrollView(child: JsonTree(value: json, autoDepth: 0, query: "deep")),
    ));
    // 无当前命中：根节点折叠，深层文本未渲染
    expect(find.textContaining("deepKey", findRichText: true), findsNothing);

    await tester.pumpWidget(wrap(
      store,
      SingleChildScrollView(
        child: JsonTree(value: json, autoDepth: 0, query: "deep", activeMatch: 1, activeKey: key),
      ),
    ));
    await tester.pump();
    // 第 2 处命中（deepValue）在最深层，沿途节点全部展开，占位 key 已挂载
    expect(find.textContaining("deepValue", findRichText: true), findsOneWidget);
    expect(key.currentContext, isNotNull);
    expect(tester.takeException(), isNull);
  });

  group("详情弹窗搜索", () {
    final String msg = List<String>.generate(
      90,
      (int i) => i == 0 || i == 50 || i == 88 ? "line $i has NEEDLE here" : "line $i filler",
    ).join("\n");
    final LogModel log = LogModel(id: 1, level: 1, timestamp: 1700000000000000, msg: msg);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final MXStore store = await createTestStore();
      await tester.pumpWidget(wrap(
        store,
        Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showLogDetailDialog(context, log: log),
              child: const Text("open"),
            ),
          ),
        ),
      ));
      await tester.tap(find.text("open"));
      await tester.pumpAndSettle();
    }

    /// 正文滚动容器（有可滚动距离的那个 Scrollable）
    ScrollPosition bodyPosition(WidgetTester tester) {
      return tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .map((ScrollableState s) => s.position)
          .firstWhere((ScrollPosition p) => p.maxScrollExtent > 0);
    }

    testWidgets("输入即计数，回车循环跳转并滚动到命中处，Shift+回车回退", (WidgetTester tester) async {
      await open(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), "needle");
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text("1 / 3"), findsOneWidget);
      // 第 1 处在首行，无需滚动
      expect(bodyPosition(tester).pixels, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text("2 / 3"), findsOneWidget);
      final double second = bodyPosition(tester).pixels;
      expect(second, greaterThan(0));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text("3 / 3"), findsOneWidget);
      expect(bodyPosition(tester).pixels, greaterThan(second));

      // 末尾再下一处回到第 1 处
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text("1 / 3"), findsOneWidget);

      // Shift+回车 → 上一处（回到最后一处）
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text("3 / 3"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets("无命中提示；Esc 先清空搜索，再按才关闭弹窗", (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), "nothing-here");
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(find.text("无匹配项"), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text("无匹配项"), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets("上一处 / 下一处按钮与计数联动", (WidgetTester tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), "needle");
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip("下一处 (Enter)"));
      await tester.pumpAndSettle();
      expect(find.text("2 / 3"), findsOneWidget);
      await tester.tap(find.byTooltip("上一处 (Shift+Enter)"));
      await tester.pumpAndSettle();
      expect(find.text("1 / 3"), findsOneWidget);
    });
  });
}
