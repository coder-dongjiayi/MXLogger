
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_repository.dart';

import '../level/mx_level.dart';
import '../storage/mxlogger_storage.dart';
import 'level_list_state.dart';


///  查询所有日志数据
final logPagesProvider = FutureProvider.autoDispose((ref) {
  final repository = ref.watch(mxloggerRepository);

  final kw = ref.watch(keywordSearchProvider);

  final list = ref.watch(levelSearchProvider);
  List<int> _level = [];
  for (var element in list) {
    if(element.selected == true){
      _level.add(element.level);
    }
  }
  if(_level.contains(-1)){
    _level = [];
  }
  final logResponse =
      repository.fetchLogs(page: null, keyWord: kw, levels: _level);

  return logResponse;
});

final pageControllerProvider = Provider((ref){

  return PageController(initialPage: 0);
});

/// 首页选择index
final selectedIndexProvider = StateProvider((ref){
  PageController controller = ref.read(pageControllerProvider);
  ref.listenSelf((previous, next) {
    if(previous != null){

        controller.jumpToPage(next);

    }
  });
  return 0;
});

final errorProvider = Provider<List<String>>((ref){
  return [];
});
/// 存储错误信息
final errorListProvider = StateProvider<List<String>>((ref){
 return [];
});

/// 显示遮罩状态
final dropTargetProvider = StateProvider((ref) => false);

/// 搜索状态
final keywordSearchProvider = StateProvider<String?>((ref) {
  return null;
});

/// 数据库数据是否为空
final emptyLogProvider = Provider.autoDispose<bool>((ref){
  final repository  =  ref.watch(mxloggerRepository);
    int count =  repository.fetchLogCount();
  return count == 0;
});

/// 保存弹框提示的状态
final cryptAlertProvider = StateProvider<bool?>((ref){
  ref.listenSelf((previous, next) {
    /// 更新本地存储状态
    MXLoggerStorage.instance.saveCryptAlert(next);
  });
  return MXLoggerStorage.instance.cryptAlert;
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





