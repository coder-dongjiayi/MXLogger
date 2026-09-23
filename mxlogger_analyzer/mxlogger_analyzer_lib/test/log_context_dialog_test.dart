import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_context_dialog.dart';

import 'support/test_store.dart';

/// 内存版上下文数据层：[total] 条日志，timestamp 1..total，msg 为 "log N"。
class ContextRepository extends EmptyRepository {
  ContextRepository({this.total = 30});

  final int total;
  final List<int> olderRequests = [];
  final List<int> newerRequests = [];

  LogModel _log(int ts) => LogModel(id: ts, level: ts % 5, timestamp: ts, msg: "log $ts");

  List<LogModel> _older(int ts, int limit) =>
      [for (int t = ts - 1; t >= 1 && t > ts - 1 - limit; t--) _log(t)];

  List<LogModel> _newer(int ts, int limit) =>
      [for (int t = ts + 1; t <= total && t < ts + 1 + limit; t++) _log(t)];

  @override
  Future<LogContext> fetchContext(LogModel anchor, {int limit = 20}) async {
    return (
      older: _older(anchor.timestamp, limit),
      newer: _newer(anchor.timestamp, limit),
      olderCount: anchor.timestamp - 1,
      total: total,
    );
  }

  @override
  Future<List<LogModel>> fetchOlderThan(int timestampUs, {int limit = 20}) async {
    olderRequests.add(timestampUs);
    return _older(timestampUs, limit);
  }

  @override
  Future<List<LogModel>> fetchNewerThan(int timestampUs, {int limit = 20}) async {
    newerRequests.add(timestampUs);
    return _newer(timestampUs, limit);
  }
}

void main() {
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

  Future<MXStore> prepare(
    WidgetTester tester, {
    required ContextRepository repository,
    Size size = const Size(1200, 2400),
    bool ascending = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final MXStore store = await createTestStore(repository: repository);
    // 卡片全部折叠，几条上下文能塞进一屏，边缘按钮无需滚动即可点到
    store.allCollapsed.value = true;
    store.filter.value = LogFilterState(ascending: ascending);
    return store;
  }

  /// 直接挂面板（小步长），验证面板自身的排布与翻页逻辑
  Future<void> pumpDialog(
    WidgetTester tester,
    MXStore store,
    ContextRepository repository,
    int anchorTs,
  ) async {
    await tester.pumpWidget(wrap(
      store,
      LogContextDialog(
        anchor: repository._log(anchorTs),
        safeInsets: EdgeInsets.zero,
        pageSize: 5,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(LogContextDialog), matching: finder);

  testWidgets("桌面端卡片操作打开上下文面板：锚点高亮、位置统计、面板内不再嵌套入口",
      (WidgetTester tester) async {
    final ContextRepository repository = ContextRepository(total: 100);
    final MXStore store = await prepare(tester, repository: repository);
    await tester.pumpWidget(wrap(store, ListView(children: [LogCard(log: repository._log(50))])));

    await tester.tap(find.byTooltip("查看上下文（全局前后日志）"));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LogContextDialog), findsOneWidget);
    // 倒序：最新的是第 1 条，ts=50 排第 51
    expect(find.text("全局第 51 条 / 共 100 条"), findsOneWidget);
    expect(find.text("不受当前筛选影响"), findsOneWidget);

    final Iterable<LogCard> cards =
        tester.widgetList<LogCard>(inDialog(find.byType(LogCard)));
    expect(cards.where((LogCard card) => card.anchored).map((LogCard c) => c.log.timestamp),
        [50]);
    expect(cards.every((LogCard card) => !card.showContext), isTrue);
    // 只有锚点卡片带实心「当前日志」标签
    expect(inDialog(find.text("当前日志")), findsOneWidget);
    // 锚点上下都有相邻日志已渲染
    expect(inDialog(find.text("log 49")), findsOneWidget);
    expect(inDialog(find.text("log 51")), findsOneWidget);
  });

  testWidgets("倒序：更新的在上、更早的在下，两端均可继续加载", (WidgetTester tester) async {
    final ContextRepository repository = ContextRepository(total: 100);
    final MXStore store = await prepare(tester, repository: repository);
    await pumpDialog(tester, store, repository, 50);

    expect(tester.takeException(), isNull);
    final Offset newer = tester.getCenter(find.text("加载更新的 5 条"));
    final Offset anchor = tester.getCenter(find.text("log 50"));
    final Offset older = tester.getCenter(find.text("加载更早的 5 条"));
    expect(newer.dy, lessThan(anchor.dy));
    expect(anchor.dy, lessThan(older.dy));
    // 更新的离锚点越近越靠下
    expect(tester.getCenter(find.text("log 51")).dy,
        greaterThan(tester.getCenter(find.text("log 55")).dy));

    await tester.tap(find.text("加载更新的 5 条"));
    await tester.pumpAndSettle();
    // 以已加载最远一条（ts=55）为游标继续往后
    expect(repository.newerRequests, [55]);
    expect(find.text("log 56"), findsOneWidget);
    // 锚点位置不因上方追加而漂移
    expect(tester.getCenter(find.text("log 50")), anchor);
  });

  testWidgets("锚点为最新一条：上方到头提示，下方翻到最早后同样到头", (WidgetTester tester) async {
    final ContextRepository repository = ContextRepository(total: 8);
    final MXStore store = await prepare(tester, repository: repository);
    await pumpDialog(tester, store, repository, 8);

    expect(find.text("已是最新的日志"), findsOneWidget);
    expect(find.text("全局第 1 条 / 共 8 条"), findsOneWidget);

    await tester.tap(find.text("加载更早的 5 条"));
    await tester.pumpAndSettle();
    // 以已加载最远一条（ts=3）为游标继续往前
    expect(repository.olderRequests, [3]);
    // 剩余 2 条不足一页，视为到头
    expect(find.text("log 1"), findsOneWidget);
    expect(find.text("已是最早的日志"), findsOneWidget);
    expect(find.text("加载更早的 5 条"), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets("列表正序时方向对调：更早的在上、更新的在下", (WidgetTester tester) async {
    final ContextRepository repository = ContextRepository(total: 100);
    final MXStore store = await prepare(tester, repository: repository, ascending: true);
    await pumpDialog(tester, store, repository, 50);

    // 正序：最早的是第 1 条
    expect(find.text("全局第 50 条 / 共 100 条"), findsOneWidget);
    final Offset older = tester.getCenter(find.text("加载更早的 5 条"));
    final Offset newer = tester.getCenter(find.text("加载更新的 5 条"));
    expect(older.dy, lessThan(newer.dy));
    expect(tester.getCenter(find.text("log 49")).dy,
        lessThan(tester.getCenter(find.text("log 51")).dy));

    await tester.tap(find.text("加载更早的 5 条"));
    await tester.pumpAndSettle();
    expect(repository.olderRequests, [45]);
  });

  testWidgets("手机端从「⋯」面板进入上下文", (WidgetTester tester) async {
    final ContextRepository repository = ContextRepository(total: 30);
    final MXStore store =
        await prepare(tester, repository: repository, size: const Size(400, 900));
    await tester.pumpWidget(wrap(store, ListView(children: [LogCard(log: repository._log(15))])));

    await tester.tap(find.byTooltip("更多操作"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("查看上下文（全局前后日志）"));
    await tester.pumpAndSettle();

    expect(find.byType(LogContextDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
