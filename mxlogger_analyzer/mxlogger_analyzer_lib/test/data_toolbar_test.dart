import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_toolbar.dart';

import 'support/test_store.dart';

/// 搜索框 × 一键清除：有内容时出现，点击立即清空关键词与输入框。
void main() {
  testWidgets("输入后显示 ×，点击立即清空搜索", (WidgetTester tester) async {
    final MXStore store = await createTestStore();
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
    await tester.pump();

    expect(find.byIcon(Icons.close), findsNothing);

    await tester.enterText(find.byType(TextField), "error");
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget);

    // 走完 180ms 防抖，关键词生效
    await tester.pump(const Duration(milliseconds: 250));
    expect(store.filter.value.keyword, "error");

    // × 一键清除：立即生效（不走防抖），输入框同步清空
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(store.filter.value.keyword, "");
    expect(find.byIcon(Icons.close), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text ?? "",
      isEmpty,
    );
  });
}
