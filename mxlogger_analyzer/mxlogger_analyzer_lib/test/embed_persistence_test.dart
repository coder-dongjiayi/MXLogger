import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/embed/mx_analyzer.dart';

/// 嵌入模式的数据是持久的：上次刷新解析出来的日志写在 sqlite 里，
/// 重启宿主 app 再唤起悬浮球仍在——`showDebug` 不得清库
/// （曾经在这里清过一次，表现就是每次重启 app 打开分析器都是空白页）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("showDebug 不清库：上次解析的日志仍在", (WidgetTester tester) async {
    final Directory dbDir = Directory.systemTemp.createTempSync("mx_db");
    final Directory logDir = Directory.systemTemp.createTempSync("mx_logs");
    addTearDown(() {
      dbDir.deleteSync(recursive: true);
      logDir.deleteSync(recursive: true);
    });

    // 上次会话解析入库的日志
    final AnalyzerDatabase seed = AnalyzerDatabase(dbDir.path)..open();
    seed.insertRecords(const <LogRecord>[
      LogRecord(
        name: "login",
        tag: "service",
        msg: "上次解析入库的日志",
        level: 1,
        threadId: 1,
        isMainThread: 1,
        timestamp: 1700000000000000,
      ),
    ]);
    seed.dispose();

    // 本次启动：宿主 app 唤起悬浮球
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Center(child: Text("host app"))),
    ));
    addTearDown(MXAnalyzer.dismiss);

    await MXAnalyzer.showDebug(
      navigatorKey.currentState!.overlay!,
      diskcachePath: logDir.path,
      databasePath: dbDir.path,
      cryptPairs: const [],
      onShare: (_) async => false,
    );
    await tester.pumpAndSettle();

    final AnalyzerDatabase reopened = AnalyzerDatabase(dbDir.path)..open();
    addTearDown(reopened.dispose);
    expect(reopened.count(), 1);
  });
}
