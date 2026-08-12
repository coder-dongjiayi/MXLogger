import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 日志列表分页状态：已加载条目 + 当前过滤条件下总条数 + 加载下一页标记。
class LogPageState {
  const LogPageState({
    this.logs = const [],
    this.total = 0,
    this.loadingMore = false,
  });

  final List<LogModel> logs;

  /// 当前过滤条件下的总条数（非已加载条数）
  final int total;

  /// 正在加载下一页（列表底部显示加载动画）
  final bool loadingMore;

  bool get hasMore => logs.length < total;

  LogPageState copyWith({List<LogModel>? logs, int? total, bool? loadingMore}) {
    return LogPageState(
      logs: logs ?? this.logs,
      total: total ?? this.total,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}
