import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/level/mx_level.dart';
import 'package:mxlogger_analyzer_lib/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';

/// 等级状态
final levelSearchProvider =
    StateNotifierProvider.autoDispose<LevelListState, List<LevelModel>>((ref) {
  List<LevelModel> levels = [];

  /// 初始化数据
  for (var element in MXLevels) {
    LevelModel model = LevelModel(
        level: element["number"],
        color: element["color"],
        levelDesc: element["level"],
        selected: false);
    levels.add(model);
  }
  return LevelListState(levels);
});

final searchResultProvider = StateProvider.autoDispose<Map<String, dynamic> >((ref) => {});

class MXLogListNotifier extends AutoDisposeAsyncNotifier<List<LogModel>> {
  bool _sort = true;

  bool get sort => _sort;

  String? _condition;
  String? _keyWord;
  List<int>? _levels;


  @override
  FutureOr<List<LogModel>> build() {
    final repository = ref.watch(mxloggerRepository);
    return repository.fetchLogs();
  }

  /// 按时间排序
  Future<void> sortSearch() {
    _sort = !_sort;
    return _loadLogSource();
  }

  /// 按等级搜索
  Future<void> levelSearch({List<int>? levels}) {
    _levels = levels;
    return _loadLogSource();
  }

  /// 条件搜索
  Future<void> conditionSearch({required String searchState,String? value}) {
    if (searchState == "keyword") {
      _condition = null;
      _keyWord = value;
    }
    ref.read(searchResultProvider)[searchState] = value;

    return _loadLogSource();
  }

  Future<void> _loadLogSource() {
    return _fetchDataSource(
        order: _sort == true ? "desc" : "asc",
        condition: _condition,
        keyWord: _keyWord,
        levels: _levels);
  }

  Future<void> _fetchDataSource(
      {String? condition,
      int? page,
      String? keyWord,
      String? order,
      List<int>? levels}) async {
    final repository = ref.read(mxloggerRepository);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => repository.fetchLogs(
        condition: condition,
        page: page,
        keyWord: keyWord,
        order: order,
        levels: levels));
  }
}

final mxLogDataSourceProvider =
    AutoDisposeAsyncNotifierProvider<MXLogListNotifier, List<LogModel>>(() {
  return MXLogListNotifier();
});
