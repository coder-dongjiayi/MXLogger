

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_repository.dart';


import '../level/mx_level.dart';

import 'level_list_state.dart';

enum AnalyzerPlatform { desktop, mobile, package }

AnalyzerPlatform analyzerPlatform = AnalyzerPlatform.desktop;

///  查询所有日志数据
final logPagesProvider = FutureProvider.autoDispose((ref) {
  final repository = ref.watch(mxloggerRepository);

  final kw = ref.watch(keywordSearchProvider);

  final list = ref.watch(levelSearchProvider);

  final sort = ref.watch(sortTimeProvider);

  List<int> _level = [];
  for (var element in list) {
    if (element.selected == true) {
      _level.add(element.level);
    }
  }
  if (_level.contains(-1)) {
    _level = [];
  }
  final logResponse = repository.fetchLogs(
      page: null,
      keyWord: kw,
      order: sort == true ? "desc" : "asc",
      levels: _level);

  return logResponse;
});

final pageControllerProvider = Provider((ref) {
  return PageController(initialPage: 0);
});



final errorProvider = Provider<List<String>>((ref) {
  return [];
});

/// 存储错误信息
final errorListProvider = StateProvider<List<String>>((ref) {
  return [];
});

/// 搜索状态
final keywordSearchProvider = StateProvider<String?>((ref) {
  return null;
});

/// 日志排序 true 按时间倒序 false 按时间正序
final sortTimeProvider = StateProvider<bool>((ref) {
  return true;
});

final packageLoadStateProvider =
    StateProvider.autoDispose<Map<String, dynamic>?>((ref) {

  return null;
});




/// 数据库数据是否为空
final emptyLogProvider = Provider.autoDispose<bool>((ref) {
  final repository = ref.watch(mxloggerRepository);
  int count = repository.fetchLogCount();
  return count == 0;
});



/// 等级状态
final levelSearchProvider =
    StateNotifierProvider<LevelListState, List<LevelModel>>((ref) {
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
