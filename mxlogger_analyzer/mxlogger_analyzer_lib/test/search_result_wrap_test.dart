import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/search_result_wrap.dart';

void main() {
  Future<List<String>> pump(WidgetTester tester,
      {required Map<String, dynamic> conditions}) async {
    final List<String> removed = [];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchResultProvider.overrideWith((ref) => conditions),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SearchResultWrap(onChange: removed.add),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return removed;
  }

  testWidgets("每条搜索条件都带一个可见的 × 按钮", (tester) async {
    await pump(tester, conditions: {"tag": "payment", "msg": "失败"});

    expect(find.textContaining("payment", findRichText: true), findsOneWidget);
    expect(find.textContaining("失败", findRichText: true), findsOneWidget);

    /// 两条条件 → 两个 ×，删除入口是看得见的，不再依赖双击
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
  });

  testWidgets("点 × 移除对应条件", (tester) async {
    final removed = await pump(tester, conditions: {"tag": "payment"});

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(removed, ["tag"]);
  });

  testWidgets("× 上有提示文案", (tester) async {
    await pump(tester, conditions: {"tag": "payment"});

    final Tooltip tooltip =
        tester.widget(find.ancestor(
      of: find.byIcon(Icons.close_rounded),
      matching: find.byType(Tooltip),
    ));
    expect(tooltip.message, "移除该条件");
  });

  testWidgets("双击 chip 不再触发移除", (tester) async {
    final removed = await pump(tester, conditions: {"tag": "payment"});

    await tester.tap(find.textContaining("payment", findRichText: true));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.textContaining("payment", findRichText: true));
    await tester.pumpAndSettle();

    expect(removed, isEmpty);
  });
}
