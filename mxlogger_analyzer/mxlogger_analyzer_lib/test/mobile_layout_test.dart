import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/crypt_entry_list.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/json_tree.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_collapsible.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/level_badge.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/level_filter_bar.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_toolbar.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

import 'support/test_store.dart';

/// 手机屏尺寸下的数据页假数据层（[logCount] 条日志，够撑出可滚动列表）。
class _FakeHomeRepository extends EmptyRepository {
  _FakeHomeRepository({this.logCount = 1, this.tags = "network,POST,200"});

  final int logCount;

  /// 逗号分隔的 tag（验证换行对齐时给一串长 tag）
  final String tags;

  LogModel _log(int index) => LogModel(
        id: index + 1,
        name: "network",
        tag: tags,
        msg: '{"uri":"https://192.168.1.1/test","statusCode":200,"i":$index}',
        level: 1,
        timestamp: 1700000000000000 + index * 1000000,
        fileHeader: '{"model":"iPhone15","systemVersion":"18.3","brand":"Apple"}',
      );

  @override
  Future<HeaderInfo> fetchHeaderInfo() async => const HeaderInfo(
        total: 5,
        minUs: 1700000000000000,
        maxUs: 1700000600000000,
        fileName: "2026-08-11_log.mx",
      );

  @override
  Future<Map<int, int>> fetchLevelCounts() async => {0: 2, 1: 1, 2: 1, 3: 1};

  @override
  Future<List<LogModel>> fetchLogs(LogFilterState filter,
          {int? limit, int? offset}) async =>
      List<LogModel>.generate(logCount, _log);

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => logCount;
}

/// 移动端适配（对齐设计稿 720 / 480 断点）：手机尺寸下不允许出现溢出，
/// 且按断点规则精简元素——widget 测试遇到 overflow 会直接失败，
/// 因此本用例同时兼作真机布局错乱的回归护栏。
void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

  /// iPhone 逻辑分辨率 390x844 + 顶部刘海 47 / 底部 home indicator 34
  void useMobileScreen() {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
  }

  tearDown(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetPadding()
      ..resetViewPadding();
  });

  Future<MXStore> pumpDataPage(
    WidgetTester tester, {
    int logCount = 1,
    String tags = "network,POST,200",
  }) async {
    final MXStore store = await createTestStore(
      repository: _FakeHomeRepository(logCount: logCount, tags: tags),
      initialPrefs: const {"mx_entered": true},
    );
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets("手机尺寸数据页：副标题与工具栏文案隐藏，等级 chips 横向滚动", (WidgetTester tester) async {
    useMobileScreen();
    await pumpDataPage(tester);

    // 副标题、工具栏按钮文案在移动端隐藏（设计稿 hide-mobile）
    expect(find.text("· 日志解析器"), findsNothing);
    expect(find.text("时间范围"), findsNothing);
    expect(find.text("折叠全部"), findsNothing);

    // 等级 chips 单行横向滚动，不换行占掉半屏
    expect(find.text("DEBUG"), findsOneWidget);
    expect(find.text("FATAL"), findsOneWidget);
    final Finder levelScroller = find.ancestor(
      of: find.text("DEBUG"),
      matching: find.byWidgetPredicate((Widget widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal),
    );
    expect(levelScroller, findsOneWidget);

    // 日志列表底部留白避开悬浮按钮并加上安全区
    final Finder list = find.byType(ListView);
    expect(list, findsOneWidget);
    final EdgeInsets padding =
        tester.widget<ListView>(list).padding! as EdgeInsets;
    // 日志区左右留白比页面留白（14）更窄，屏幕窄，边距吃的都是正文宽度
    expect(padding.left, 2);
    expect(padding.bottom, 96 + 34);

    // 时间范围面板：两个输入竖排铺满（并排定宽会溢出）
    await tester.tap(find.byIcon(Icons.access_time));
    await tester.pumpAndSettle();
    expect(find.text("应用"), findsOneWidget);
    final List<Size> timeFieldSizes = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((TextField field) => tester.getSize(find.byWidget(field)))
        .toList();
    // 搜索框 + 两个时间输入
    expect(timeFieldSizes.length, 3);
    expect(timeFieldSizes[1].width, greaterThan(190));
  });

  testWidgets("手机尺寸桌面元素回归：宽屏仍显示副标题与文案", (WidgetTester tester) async {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    await pumpDataPage(tester);

    expect(find.text("· 日志解析器"), findsOneWidget);
    expect(find.text("时间范围"), findsOneWidget);
    final EdgeInsets padding =
        tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;
    expect(padding.left, 20);
    expect(padding.bottom, 80);
  });

  testWidgets("左下角按钮收起筛选区：等级条/chips/搜索/时间/折叠一起收，品牌行留着",
      (WidgetTester tester) async {
    useMobileScreen();
    await pumpDataPage(tester, logCount: 30);

    final Finder list = find.byType(ListView);
    final double expandedTop = tester.getTopLeft(list).dy;
    // 筛选区（等级条+chips+搜索工具栏）本身占了不少高度
    expect(expandedTop, greaterThan(150));

    // 左下角按钮：在屏幕左半边、底部
    final Finder toggle = find.byIcon(Icons.expand_less);
    expect(toggle, findsOneWidget);
    final Offset center = tester.getCenter(toggle);
    expect(center.dx, lessThan(390 / 2));
    expect(center.dy, greaterThan(844 * 0.7));

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    // 列表上移占满，按钮反向
    expect(tester.getTopLeft(list).dy, lessThan(expandedTop - 100));
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    // 品牌行与右上角操作仍在
    expect(find.byType(MXLogo), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    // 两块收起区（等级筛选 + 搜索工具栏）占位归零，
    // 但子树仍挂载（搜索框内容与焦点不丢）
    final Finder collapsibles = find.byType(MXCollapsible);
    expect(collapsibles, findsNWidgets(2));
    for (final Element element in collapsibles.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, 0);
    }
    expect(find.byType(DataToolbar), findsOneWidget);
    expect(find.byType(LevelFilterBar), findsOneWidget);

    // 再点一次还原
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(list).dy, expandedTop);
  });

  testWidgets("桌面端没有收起筛选区的悬浮按钮", (WidgetTester tester) async {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1.0;
    await pumpDataPage(tester, logCount: 30);

    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
  });

  testWidgets("手机端日志卡片：4 个操作收进「⋯」，默认折叠，时间显示完整年月日", (WidgetTester tester) async {
    useMobileScreen();
    final MXStore store = await pumpDataPage(tester);

    // 卡片头部只剩「⋯」，4 个图标都收起来了
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    for (final IconData icon in <IconData>[
      Icons.info_outline,
      Icons.share_outlined,
      Icons.fullscreen,
      Icons.copy_outlined,
    ]) {
      expect(
        find.descendant(of: find.byType(LogCard), matching: find.byIcon(icon)),
        findsNothing,
      );
    }

    // 时间不再只留时分秒
    final MxTimeParts time =
        mxFmtTs(DateTime.fromMicrosecondsSinceEpoch(1700000000000000));
    expect(
      find.byWidgetPredicate((Widget widget) =>
          widget is Text &&
          (widget.textSpan?.toPlainText() ?? "").startsWith("${time.date} ${time.time}")),
      findsOneWidget,
    );

    // 手机端默认折叠：只显示单行预览，正文（JSON 树）不渲染
    expect(store.allCollapsed.value, isTrue);
    expect(find.byType(JsonTree), findsNothing);
    // 点折叠钮单条展开，默认态不受影响
    await tester.tap(find.text("▾"));
    await tester.pumpAndSettle();
    expect(find.byType(JsonTree), findsOneWidget);
    expect(store.allCollapsed.value, isTrue);

    // 点「⋯」从底部弹出 4 个操作
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text("查看这条日志的 Header"), findsOneWidget);
    expect(find.text("分享这条日志"), findsOneWidget);
    expect(find.text("全屏查看"), findsOneWidget);
    expect(find.text("复制这条日志"), findsOneWidget);

    // 面板底部避让 home indicator（34）
    final Finder sheet = find.ancestor(
      of: find.text("全屏查看"),
      matching: find.byType(Container),
    );
    expect(tester.getBottomLeft(sheet.last).dy, 844);
    expect(tester.getBottomLeft(find.text("复制这条日志")).dy, lessThan(844 - 34));
  });

  testWidgets("换行的 tag 与等级徽标左对齐（不是缩到折叠箭头下）", (WidgetTester tester) async {
    useMobileScreen();
    // 多个长 tag，必定换行
    await pumpDataPage(
      tester,
      tags: "network,login,payment,checkout,settlement,retry,timeout",
    );

    final double arrowLeft = tester.getTopLeft(find.text("▾")).dx;
    final double badgeLeft = tester.getTopLeft(find.byType(LevelBadge)).dx;
    // 折叠钮在标签区之外，标签区整体缩进到它右边
    expect(badgeLeft, greaterThan(arrowLeft));

    // 换行的 tag 落在标签区左边缘 = 等级徽标左边缘
    final Finder wrap =
        find.descendant(of: find.byType(LogCard), matching: find.byType(Wrap));
    final Rect wrapRect = tester.getRect(wrap.first);
    expect(wrapRect.left, badgeLeft);
    // 确实换了行（标签区高度超过单行）
    expect(wrapRect.height, greaterThan(30));
  });

  testWidgets("手机尺寸弹窗铺满整屏并避让安全区", (WidgetTester tester) async {
    useMobileScreen();
    await pumpDataPage(tester);

    // 全屏查看单条日志（手机端从「⋮」面板进）
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text("全屏查看"));
    await tester.pumpAndSettle();
    final Size dialogSize = tester.getSize(find.byType(Dialog));
    expect(dialogSize.width, 390);
    expect(dialogSize.height, 844);
    // 底栏三个按钮等宽平分
    expect(find.text("分享"), findsOneWidget);
    expect(find.text("关闭"), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    // 每条日志的 Header 弹窗同样铺满
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text("查看这条日志的 Header"));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Dialog)).width, 390);
  });

  testWidgets("手机尺寸首次引导页：KEY/IV 竖排铺满，无溢出", (WidgetTester tester) async {
    useMobileScreen();
    final MXStore store = await createTestStore();
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 第一步 → 第二步（KEY/IV）
    store.wizardPaths.value = const ["/tmp/a.mx"];
    await tester.pumpAndSettle();
    await tester.tap(find.text("下一步"));
    await tester.pumpAndSettle();

    expect(find.text("开始导入"), findsOneWidget);
    // KEY/IV 各占一行并铺满剩余宽度（而非并排定宽 150）
    final List<Size> fieldSizes = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((TextField field) => tester.getSize(find.byWidget(field)))
        .toList();
    expect(fieldSizes.length, 2);
    for (final Size size in fieldSizes) {
      expect(size.width, greaterThan(150));
    }

    // 再加两组：每组仍是 KEY/IV 竖排铺满，卡片不溢出（溢出会让本用例失败）
    await tester.tap(find.text("添加一组"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("添加一组"));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(6));
    // 勾选框里的序号即解密尝试顺序（步骤条也有数字，故限定在编辑器内查找）
    for (final String order in ["1", "2", "3"]) {
      expect(
        find.descendant(
            of: find.byType(CryptEntryList), matching: find.text(order)),
        findsOneWidget,
      );
    }
    for (final TextField field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(tester.getSize(find.byWidget(field)).width, greaterThan(150));
    }
  });
}
