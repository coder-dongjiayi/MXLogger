import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/level/mx_level.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';

enum AnalyzerPlatform { desktop, mobile, package }

AnalyzerPlatform analyzerPlatform = AnalyzerPlatform.desktop;

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

final searchResultProvider =
    StateProvider.autoDispose<Map<String, dynamic>>((ref) => {});

class MXLogListNotifier extends AutoDisposeAsyncNotifier<({bool? isSearch,List<LogModel> dataSource})> {
  bool _sort = true;

  bool get sort => _sort;

  String? _condition;
  String? _keyWord;
  List<int>? _levels;

  bool get searchCondition =>
      _condition != null || _keyWord != null || _levels?.isNotEmpty == true;

  @override
  FutureOr<({bool? isSearch,List<LogModel> dataSource})> build() async{
    final repository = ref.watch(mxloggerRepository);
    final dataSource =  await repository.fetchLogs();
    return (isSearch:false,dataSource:dataSource);
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

  /// 关键词搜索
  Future<void> _keywordSearch({String? keyWord}) {
    _keyWord = keyWord;
    _condition = null;
    return _loadLogSource();
  }

  /// 条件搜索
  Future<void> _conditionSearch({required Map<String, dynamic> map}) {
    _keyWord = null;
    _condition = _getCondition(map);
    return _loadLogSource();
  }

  String? _getCondition(Map<String, dynamic> map) {
    if (map.isEmpty == true) return null;
    List<String> list = [];
    map.forEach((key, value) {
      String sql = "$key like '%$value%'";
      list.add(sql);
    });
    return list.join(" and ");
  }

  Future<void> deleteSearch({required String searchState}) {
    Map<String, dynamic> map = ref.read(searchResultProvider);
    map.remove(searchState);
    if (searchState == "keyword") {
      ref.read(searchResultProvider.notifier).state = map;
      return _keywordSearch(keyWord: null);
    }
    ref.read(searchResultProvider.notifier).state = map;
    String? condition = _getCondition(map);
    _keyWord = null;
    _condition = condition;
    return _loadLogSource();
  }

  Future<void> search({required String searchState, String? value}) {
    Map<String, dynamic> map = ref.read(searchResultProvider);
    if (searchState == "keyword") {
      map.clear();
      map[searchState] = value;

      ref.read(searchResultProvider.notifier).state = map;

      return _keywordSearch(keyWord: value);
    }
    map.remove("keyword");
    map[searchState] = value;
    ref.read(searchResultProvider.notifier).state = map;

    return _conditionSearch(map: map);
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
    state = await AsyncValue.guard(() async{
     final dataSource = await repository.fetchLogs(
          searchCondition: condition,
          page: page,
          keyWord: keyWord,
          order: order,
          levels: levels);
     return (isSearch:searchCondition,dataSource:dataSource);
    });
  }
}

final mxLogDataSourceProvider =
    AutoDisposeAsyncNotifierProvider<MXLogListNotifier, ({bool? isSearch,List<LogModel> dataSource})>(() {
  return MXLogListNotifier();
});
