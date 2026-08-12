import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/provider/advanced_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/advanced_filter_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/log_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 面板底部会读取日志条数，测试里不连数据库
class _FakeLogNotifier extends MXLogListNotifier {
  @override
  Future<({bool? isSearch, List<LogModel> dataSource})> build() async =>
      (isSearch: false, dataSource: <LogModel>[]);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group("过滤条件生成", () {
    test("没有规则时不产生条件", () {
      expect(const AdvancedFilter().sqlCondition, isNull);
    });

    test("白名单只保留命中的日志", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "payment", field: FilterField.tag),
      ]);
      expect(filter.sqlCondition, "(ifnull(tag,'') like '%payment%')");
    });

    test("黑名单取反，且用 ifnull 兜底避免误伤字段为 NULL 的行", () {
      const filter = AdvancedFilter(blacklist: [
        FilterRule(keyword: "heartbeat", field: FilterField.msg),
      ]);
      expect(filter.sqlCondition, "not (ifnull(msg,'') like '%heartbeat%')");
    });

    test("同一名单内多条规则之间是 or", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "payment", field: FilterField.tag),
        FilterRule(keyword: "rtc", field: FilterField.tag),
      ]);
      expect(filter.sqlCondition,
          "(ifnull(tag,'') like '%payment%' or ifnull(tag,'') like '%rtc%')");
    });

    test("字段选全部时 msg/tag/name 任一命中即可", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "失败", field: FilterField.all),
      ]);
      expect(
          filter.sqlCondition,
          "(ifnull(msg,'') like '%失败%' or ifnull(tag,'') like '%失败%' "
          "or ifnull(name,'') like '%失败%')");
    });

    test("白名单和黑名单同时生效时用 and 串起来", () {
      const filter = AdvancedFilter(
        whitelist: [FilterRule(keyword: "payment", field: FilterField.tag)],
        blacklist: [FilterRule(keyword: "Bundle", field: FilterField.msg)],
      );
      expect(
          filter.sqlCondition,
          "(ifnull(tag,'') like '%payment%') and "
          "not (ifnull(msg,'') like '%Bundle%')");
    });

    test("取消选择的规则不参与过滤", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "payment", field: FilterField.tag, enabled: false),
        FilterRule(keyword: "rtc", field: FilterField.tag),
      ]);
      expect(filter.sqlCondition, "(ifnull(tag,'') like '%rtc%')");
    });

    test("全部取消选择等于没有过滤", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "payment", field: FilterField.tag, enabled: false),
      ]);
      expect(filter.sqlCondition, isNull);
    });

    test("关键词里的单引号被转义，不会截断 SQL", () {
      const filter = AdvancedFilter(whitelist: [
        FilterRule(keyword: "it's", field: FilterField.msg),
      ]);
      expect(filter.sqlCondition, "(ifnull(msg,'') like '%it''s%')");
    });
  });

  group("名单增删改", () {
    test("添加、切换、删除", () {
      final notifier = AdvancedFilterState();

      notifier.add(FilterListType.white,
          keyword: "payment", field: FilterField.tag);
      expect(notifier.state.whitelist.length, 1);
      expect(notifier.state.enabledCount, 1);

      final rule = notifier.state.whitelist.first;
      notifier.toggle(FilterListType.white, rule);
      expect(notifier.state.whitelist.first.enabled, false);
      expect(notifier.state.enabledCount, 0);

      notifier.remove(FilterListType.white, rule);
      expect(notifier.state.whitelist, isEmpty);
    });

    test("重复添加同字段同关键词不会产生第二条，而是重新启用", () {
      final notifier = AdvancedFilterState();
      notifier.add(FilterListType.black,
          keyword: "heartbeat", field: FilterField.msg);
      notifier.toggle(FilterListType.black, notifier.state.blacklist.first);
      expect(notifier.state.blacklist.first.enabled, false);

      notifier.add(FilterListType.black,
          keyword: "heartbeat", field: FilterField.msg);
      expect(notifier.state.blacklist.length, 1);
      expect(notifier.state.blacklist.first.enabled, true);
    });

    test("同关键词不同字段是两条独立规则", () {
      final notifier = AdvancedFilterState();
      notifier.add(FilterListType.white,
          keyword: "upload", field: FilterField.tag);
      notifier.add(FilterListType.white,
          keyword: "upload", field: FilterField.msg);
      expect(notifier.state.whitelist.length, 2);
    });

    test("空白关键词不会被添加", () {
      final notifier = AdvancedFilterState();
      notifier.add(FilterListType.white, keyword: "   ", field: FilterField.all);
      expect(notifier.state.whitelist, isEmpty);
    });

    test("全选 / 全不选", () {
      final notifier = AdvancedFilterState();
      notifier.add(FilterListType.white, keyword: "a", field: FilterField.tag);
      notifier.add(FilterListType.white, keyword: "b", field: FilterField.tag);

      notifier.toggleAll(FilterListType.white, false);
      expect(notifier.state.enabledCount, 0);
      notifier.toggleAll(FilterListType.white, true);
      expect(notifier.state.enabledCount, 2);
    });
  });

  group("面板交互", () {
    Future<void> pumpDialog(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          mxLogDataSourceProvider.overrideWith(() => _FakeLogNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AdvancedFilterDialog()),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets("输入关键词后回车即添加成 chip", (tester) async {
      await pumpDialog(tester);

      expect(find.text("白名单"), findsOneWidget);
      expect(find.text("黑名单"), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, "payment");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text("payment"), findsOneWidget);
      expect(find.text("1 条生效"), findsOneWidget);
    });

    testWidgets("点击 chip 取消选择，条目保留但不再生效", (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField).first, "payment");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.tap(find.text("payment"));
      await tester.pumpAndSettle();

      /// 条目还在，但角标消失
      expect(find.text("payment"), findsOneWidget);
      expect(find.text("1 条生效"), findsNothing);
    });

    testWidgets("白名单和黑名单互不干扰", (tester) async {
      await pumpDialog(tester);

      await tester.enterText(find.byType(TextField).at(0), "payment");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), "heartbeat");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text("payment"), findsOneWidget);
      expect(find.text("heartbeat"), findsOneWidget);
      expect(find.text("2 条生效"), findsOneWidget);
    });

    testWidgets("切换字段后添加的规则带字段前缀", (tester) async {
      await pumpDialog(tester);

      /// 每个分区的字段选择依次是 全部 / tag / name / msg
      await tester.tap(find.text("tag").first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, "payment");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text("tag:"), findsOneWidget);
    });
  });
}
