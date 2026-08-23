import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/header_dialog.dart';

/// 回归：单条日志 Header 弹窗（标量网格 + 嵌套 JSON 树）不允许出现布局异常。
void main() {
  const Map<String, Object?> header = {
    "app_version": "2.4.1 (build 20260701)",
    "os": "iOS 19.2",
    "locale": "zh-Hans-CN",
    "env": "production",
    "retention_days": 7,
    "push_enabled": true,
    "device": {
      "model": "iPhone 16 Pro",
      "screen": {"width": 1206, "height": 2622, "scale": 3},
      "jailbroken": false,
    },
    "flags": ["newHomePage", "speechV2"],
  };

  final LogModel log = LogModel(
    id: 1,
    level: 1,
    timestamp: 1700000000000000,
    msg: "hello",
    fileHeader: jsonEncode(header),
  );

  Widget buildApp() {
    return MaterialApp(
      theme: MXTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale("zh"),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: ElevatedButton(
              onPressed: () => showLogHeaderDialog(context, log: log),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets("Header 弹窗渲染标量网格与嵌套树，无布局异常", (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // 标量 key 按日志原样展示（不做大写转换）
    expect(find.text("app_version"), findsOneWidget);
    expect(find.textContaining("APP_VERSION"), findsNothing);
    // 嵌套字段整行展示 key + 尺寸标注
    expect(find.text("device"), findsOneWidget);
    expect(find.textContaining("3 键"), findsWidgets);
  });

  testWidgets("无 header 的日志展示空态提示", (WidgetTester tester) async {
    final LogModel empty = LogModel(id: 2, level: 0, timestamp: 1, msg: "x");
    await tester.pumpWidget(
      MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale("zh"),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => showLogHeaderDialog(context, log: empty),
                child: const Text("open"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
    expect(find.text("该日志无 Header 信息"), findsOneWidget);
  });
}
