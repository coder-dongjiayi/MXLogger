import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/embed/mx_analyzer.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

import 'support/test_store.dart';

/// 有一条日志的假数据层（够渲染日志卡片上的各操作按钮）。
class _FakeHomeRepository extends EmptyRepository {
  static final LogModel _log = LogModel(
    id: 1,
    name: "network",
    tag: "network",
    msg: "hello",
    level: 1,
    timestamp: 1700000000000000,
    fileHeader: '{"model":"iPhone15"}',
  );

  @override
  Future<HeaderInfo> fetchHeaderInfo() async =>
      const HeaderInfo(total: 1, fileName: "log.mx");

  @override
  Future<Map<int, int>> fetchLevelCounts() async => {1: 1};

  @override
  Future<List<LogModel>> fetchLogs(LogFilterState filter,
          {int? limit, int? offset}) async =>
      [_log];

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => 1;
}

/// 嵌入模式弹窗必须留在分析器自己的 Navigator 里：
/// MXScope / 主题 / AppLocalizations 都只存在于弹窗内的嵌套 MaterialApp，
/// 若 showDialog 走宿主 root navigator（Flutter 默认），
/// 会抛「组件树上缺少 MXScope」或 l10n 取不到。
///
/// 宿主 app 故意只有一个裸 MaterialApp（无 MXScope、无 localizationsDelegates），
/// 与真机上的 MXAnalyzer.showDebug 结构一致。
void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  testWidgets("宿主 app 内打开各弹窗不脱离分析器组件树", (WidgetTester tester) async {
    final MXStore store = await createTestStore(
      repository: _FakeHomeRepository(),
      // 嵌套 app 的语言由 store 决定（测试环境系统语言是英文，这里固定中文断言）
      initialPrefs: const {"mx_entered": true, "mxlogger-locale": "zh"},
      diskcachePath: "/tmp/mx_not_exists",
    );

    await tester.pumpWidget(
      // 宿主 app：没有 MXScope，也没有配 AppLocalizations
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: Center(child: Text("host app"))),
              // 与 MXAnalyzer 底部弹窗等价的嵌套结构
              Expanded(flex: 5, child: MXAnalyzerEmbedApp(store: store)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 手机端 4 个操作收在「⋮」里：底部操作面板同样不能脱离分析器组件树
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    // 全屏查看单条日志
    await tester.tap(find.text("全屏查看"));
    await tester.pumpAndSettle();
    expect(find.text("Name"), findsOneWidget);
    await tester.tap(find.text("关闭").last);
    await tester.pumpAndSettle();

    // 单条日志的 Header 弹窗
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text("查看这条日志的 Header"));
    await tester.pumpAndSettle();
    expect(find.text("Header"), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // 清空数据二次确认弹框
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text("清空数据"), findsOneWidget);
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();
  });
}
