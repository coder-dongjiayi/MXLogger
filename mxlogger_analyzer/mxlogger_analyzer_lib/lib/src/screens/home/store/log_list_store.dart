import 'dart:async';

import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_page_state.dart';

/// 日志列表（分页）：过滤条件变化自动重查第一页，滚动到底部加载下一页。
class LogListStore extends MXAsyncState<LogPageState> {
  LogListStore(this._store) {
    // 过滤条件变化即重查第一页（尚未被观察过时不空跑）
    _filterSubscription = _store.filter.stream.listen((_) => refresh());
  }

  /// 每页条数
  static const int pageSize = 50;

  final MXStore _store;
  late final StreamSubscription<LogFilterState> _filterSubscription;

  @override
  Future<LogPageState> load() async {
    final LogFilterState filter = _store.filter.value;
    final int total = await _store.repository.fetchLogsCount(filter);
    final List<LogModel> logs =
        await _store.repository.fetchLogs(filter, limit: pageSize, offset: 0);
    return LogPageState(logs: logs, total: total);
  }

  /// 加载下一页并追加到列表尾部。
  /// 本地查询极快，取到数据后保底延迟 1 秒，让底部加载动画可被感知。
  Future<void> loadMore() async {
    final LogPageState? current = value.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    final int generation = this.generation;
    final LogPageState loading = current.copyWith(loadingMore: true);
    setData(loading);

    final List<LogModel> next = await _store.repository.fetchLogs(
      _store.filter.value,
      limit: pageSize,
      offset: current.logs.length,
    );
    await Future<void>.delayed(const Duration(seconds: 1));

    // 等待期间过滤条件变化会触发重查，丢弃迟到的追加结果
    if (isDisposed ||
        generation != this.generation ||
        !identical(value.valueOrNull, loading)) {
      return;
    }

    // 新加载的日志自动跟随默认折叠态（折叠态是「默认 + 单条翻转」模型，
    // 不需要在这里逐条登记 id）
    setData(current.copyWith(logs: [...current.logs, ...next], loadingMore: false));
  }

  @override
  void dispose() {
    _filterSubscription.cancel();
    super.dispose();
  }
}
