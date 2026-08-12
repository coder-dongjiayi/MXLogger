import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_page_state.dart';

import 'support/test_store.dart';

/// 内存假数据层：120 条日志，支持 keyword 过滤 + limit/offset 切片。
class _PagedRepository extends EmptyRepository {
  static final List<LogModel> all = [
    for (int i = 0; i < 120; i++)
      LogModel(id: i + 1, level: 0, timestamp: i + 1, msg: "log $i"),
  ];

  List<LogModel> _filtered(LogFilterState filter) => filter.keyword.isEmpty
      ? all
      : all.where((LogModel log) => log.msg!.contains(filter.keyword)).toList();

  @override
  Future<List<LogModel>> fetchLogs(LogFilterState filter, {int? limit, int? offset}) async {
    final List<LogModel> filtered = _filtered(filter);
    if (limit == null) return filtered;
    return filtered.skip(offset ?? 0).take(limit).toList();
  }

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => _filtered(filter).length;
}

void main() {
  late MXStore store;

  setUp(() async {
    store = await createTestStore(repository: _PagedRepository());
  });

  test("首次构建只加载第一页 50 条，total 为过滤总数", () async {
    final LogPageState page = await store.logList.future;
    expect(page.logs.length, 50);
    expect(page.total, 120);
    expect(page.hasMore, isTrue);
    expect(page.logs.first.id, 1);
  });

  test("loadMore 追加下一页，取数后保底延迟 1 秒展示加载动画", () async {
    await store.logList.future;

    final Stopwatch stopwatch = Stopwatch()..start();
    final Future<void> loading = store.logList.loadMore();
    // 加载中标记立即置位（列表底部据此显示脉冲动画）
    expect(store.logList.value.value!.loadingMore, isTrue);

    await loading;
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(1000));

    final LogPageState page = store.logList.value.value!;
    expect(page.loadingMore, isFalse);
    expect(page.logs.length, 100);
    expect(page.logs[50].id, 51);

    // 末页只剩 20 条，加载完 hasMore 归零，重复调用不再变化
    await store.logList.loadMore();
    expect(store.logList.value.value!.logs.length, 120);
    expect(store.logList.value.value!.hasMore, isFalse);
    await store.logList.loadMore();
    expect(store.logList.value.value!.logs.length, 120);
  });

  test("「折叠全部」开启时，新加载页的日志无需登记 id 也跟随折叠", () async {
    await store.logList.future;
    store.allCollapsed.value = true;
    // 单条翻转过一条：它保持与默认相反（展开）
    store.foldToggled.value = const {1};

    await store.logList.loadMore();

    bool foldedOf(int id) =>
        store.foldToggled.value.contains(id) != store.allCollapsed.value;
    expect(foldedOf(51), isTrue);
    expect(foldedOf(100), isTrue);
    expect(foldedOf(1), isFalse);
    // 翻转集不随分页膨胀
    expect(store.foldToggled.value, const {1});
  });

  test("加载下一页期间过滤条件变化，迟到的追加结果被丢弃", () async {
    await store.logList.future;

    final Future<void> loading = store.logList.loadMore();
    // 1 秒延迟窗口内改变过滤条件触发重查
    store.filter.value = const LogFilterState(keyword: "log 1");
    await loading;
    final LogPageState page = await store.logList.future;

    // "log 1" 前缀命中 log 1 / log 1x / log 1xx 共 31 条，未混入旧列表的追加页
    expect(page.total, 31);
    expect(page.logs.length, 31);
    expect(page.loadingMore, isFalse);
  });
}
