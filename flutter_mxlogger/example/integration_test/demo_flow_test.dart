import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:example/main.dart' as app;

/// 轮询等待某个 widget 出现(integration test 里等待真实异步任务完成)
Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
    {Duration timeout = const Duration(seconds: 90)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('超时未找到: $finder');
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 让 pump 的每一帧都真实上屏，否则 iOS 原生截图会拿到滞后的屏幕内容(弹窗/转场缺失)
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final platform = Platform.operatingSystem; // 截图名带平台前缀，两端结果并存

  testWidgets('MXLogger demo 全流程', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Android 上截图前必须先把 surface 转成 image
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }

    // ---- 落地页 ----
    expect(find.text('MXLogger'), findsOneWidget);
    expect(find.text('进入演示控制台'), findsOneWidget);
    await binding.takeScreenshot('$platform-01-landing');

    // ---- 进入控制台(等待 logger 初始化完成) ----
    await tester.tap(find.text('进入演示控制台'));
    await pumpUntilFound(tester, find.text('日志写入'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('$platform-02-home');

    // ---- 各等级写入 ----
    for (final title in ['写入 Debug 日志', '写入 Info 日志', '写入 Warn 日志']) {
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 250));
    }

    final scrollable = find.byType(Scrollable).first;
    for (final title in ['写入网络请求日志', 'log() 通用写入', '通过 loggerKey 写入']) {
      await tester.scrollUntilVisible(find.text(title), 120,
          scrollable: scrollable);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(find.text(title));
      await tester.pump(const Duration(milliseconds: 250));
    }
    // 等最后一个 toast 消失，避免遮挡后续点击
    await tester.pump(const Duration(milliseconds: 1800));

    // ---- 多 isolate 并发写入 + 自动校验 ----
    await tester.scrollUntilVisible(find.text('多 isolate 并发写入'), 120,
        scrollable: scrollable);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('多 isolate 并发写入'));
    await pumpUntilFound(tester, find.textContaining('并发校验'),
        timeout: const Duration(seconds: 120));
    expect(find.text('✅ 并发校验通过'), findsOneWidget,
        reason: '并发写入自检应通过(条数与顺序完整)');
    await tester.pumpAndSettle(); // 等弹窗淡入动画完成再截图
    await binding.takeScreenshot('$platform-03-concurrent-verify');
    await tester.tap(find.text('好'));
    await tester.pump(const Duration(milliseconds: 400));

    // ---- 浏览日志文件 ----
    await tester.scrollUntilVisible(find.text('浏览日志文件'), 120,
        scrollable: scrollable);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('浏览日志文件'));
    await pumpUntilFound(tester, find.textContaining('个文件'));
    await tester.pumpAndSettle(); // 等转场动画与 toast 结束
    expect(find.byIcon(Icons.description), findsWidgets,
        reason: '应至少有一个日志文件');
    await binding.takeScreenshot('$platform-04-file-list');

    // ---- 打开第一个文件 → 查看器(等待后台解析完成) ----
    // 等 INFO 徽标出现: 该文本只在解析完成后的记录列表里存在，
    // 不能用"并发写入"之类的文案——Navigator 栈里主页的行标题会误匹配
    await tester.tap(find.byIcon(Icons.description).first);
    await pumpUntilFound(tester, find.text('INFO'),
        timeout: const Duration(seconds: 120));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('$platform-05-viewer');

    // ---- 筛选: Info 等级 + 关键字搜索 ----
    await tester.tap(find.text('Info'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('并发写入'), findsWidgets);
    await tester.enterText(find.byType(TextField), '长消息');
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('payload-'), findsWidgets,
        reason: '搜索"长消息"应命中并发测试里的长消息日志');
    await binding.takeScreenshot('$platform-06-viewer-filter');
  });
}
