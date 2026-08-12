import 'package:flutter_test/flutter_test.dart';

import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 不触达数据库的假数据层：子类按需覆写查询，未覆写的查询会抛出。
class FakeRepository extends HomeRepository {
  FakeRepository() : super(_noDatabase);

  static Future<AnalyzerDatabase> _noDatabase() =>
      throw UnimplementedError("测试未提供数据库");
}

/// 空数据的假数据层：页面渲染所需的查询全部返回空结果。
class EmptyRepository extends FakeRepository {
  @override
  Future<HeaderInfo> fetchHeaderInfo() async => const HeaderInfo();

  @override
  Future<Map<int, int>> fetchLevelCounts() async => const {};

  @override
  Future<List<LogModel>> fetchLogs(LogFilterState filter, {int? limit, int? offset}) async =>
      const [];

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => 0;

  @override
  Future<List<String>> fetchTagOptions() async => const [];

  @override
  Future<List<String>> fetchNameOptions() async => const [];
}

/// 构建测试用 store：默认空数据层，不触达 sqlite / path_provider，
/// 设置存内存（MXMemoryPrefs），无选文件/拖入能力——与嵌入模式默认值一致；
/// 需要桌面壳能力的测试可传 [host] 注入假实现。
/// 传 [diskcachePath] 即模拟嵌入模式（日志来源固定为本机目录）。
Future<MXStore> createTestStore({
  HomeRepository? repository,
  Map<String, Object> initialPrefs = const {},
  String? diskcachePath,
  MXHost? host,
}) async {
  final MXStore store = MXStore(
    host: host ?? MXHost(prefs: MXMemoryPrefs(initialPrefs)),
    repository: repository ?? EmptyRepository(),
    diskcachePath: diskcachePath,
  );
  addTearDown(store.dispose);
  return store;
}
