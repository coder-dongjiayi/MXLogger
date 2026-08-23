import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';

import 'support/test_store.dart';

/// 回归：超长正文的日志卡片展开时限高截断（渐隐 + 「查看完整」按钮），
/// 不允许单条日志把列表撑出几十行；短正文不出现截断按钮。
void main() {
  LogModel buildLog({required int id, required String msg}) {
    return LogModel(id: id, level: 1, timestamp: 1700000000000000, msg: msg);
  }

  Widget buildApp(MXStore store, LogModel log) {
    return MXScope(
      store: store,
      child: MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("zh"),
        home: Scaffold(
          body: ListView(children: [LogCard(log: log)]),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, LogModel log) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final MXStore store = await createTestStore();
    await tester.pumpWidget(buildApp(store, log));
    // 溢出检测在布局后一帧才生效
    await tester.pump();
  }

  testWidgets("超长文本正文被限高截断并显示「查看完整」", (WidgetTester tester) async {
    final String msg =
        List<String>.generate(60, (int i) => "line ${i + 1}").join("\n");
    await pump(tester, buildLog(id: 1, msg: msg));

    expect(find.textContaining("查看完整"), findsOneWidget);
    expect(find.textContaining("共 60 行"), findsOneWidget);
    // 卡片整体高度受限（正文 280 + 头部与内边距）
    final double cardHeight = tester.getSize(find.byType(LogCard)).height;
    expect(cardHeight, lessThan(400));
  });

  testWidgets("点击「查看完整」打开全屏详情弹窗", (WidgetTester tester) async {
    final String msg =
        List<String>.generate(60, (int i) => "line ${i + 1}").join("\n");
    await pump(tester, buildLog(id: 1, msg: msg));

    await tester.tap(find.textContaining("查看完整"));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets("短正文不出现截断按钮", (WidgetTester tester) async {
    await pump(tester, buildLog(id: 2, msg: "short line"));
    expect(find.textContaining("查看完整"), findsNothing);
  });

  testWidgets("超长 JSON 正文同样被限高截断", (WidgetTester tester) async {
    final String msg =
        "{\"items\":[${List<String>.generate(80, (int i) => "{\"k$i\":$i}").join(",")}]}";
    await pump(tester, buildLog(id: 3, msg: msg));

    expect(find.textContaining("查看完整"), findsOneWidget);
    final double cardHeight = tester.getSize(find.byType(LogCard)).height;
    expect(cardHeight, lessThan(400));
  });
}
