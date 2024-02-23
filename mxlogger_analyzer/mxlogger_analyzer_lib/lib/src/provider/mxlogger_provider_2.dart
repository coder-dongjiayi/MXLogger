

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_repository.dart';


import '../level/mx_level.dart';

import 'level_list_state.dart';
import 'mxlogger_provider.dart';

enum AnalyzerPlatform { desktop, mobile, package }

AnalyzerPlatform analyzerPlatform = AnalyzerPlatform.desktop;


///  查询所有日志数据
final logPagesProvider = FutureProvider.autoDispose((ref) {
  final repository = ref.watch(mxloggerRepository);

  String? kw = ref.watch(keywordSearchProvider);

  final list = ref.watch(levelSearchProvider);

  final sort = ref.watch(sortTimeProvider);

  final condition = ref.watch(propertySearchProvider);

  String searchCondition = (condition ?? "msg").replaceAll(":", "");

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
      condition: condition == null ? null : searchCondition,
      keyWord: kw,
      order: sort == true ? "desc" : "asc",
      levels: _level);

  return logResponse;
});


final textEditingControllerProvider = Provider<TextEditingController>((ref){
  TextEditingController controller = TextEditingController();

  return controller;
});



final  conditionProvider= StateProvider.autoDispose<String?>((ref){
  ref.listenSelf((previous, next) {
    if(next != null){
      ref.read(textEditingControllerProvider).text = "";
    }
  });
  String? search =  ref.watch(searchTextChangeProvider);
  if(search == "tag:") return "tag:";
  if(search == "name:") return "name:";
  if(search == "msg:") return "msg:";
  return  null;
});

final searchHitTextProvider = Provider.autoDispose<String>((ref){
  String? condition  = ref.watch(conditionProvider);

  bool desktop  = analyzerPlatform == AnalyzerPlatform.desktop;
  if(condition == "tag:"){
    return "搜索多个tag，可使用空格进行分割${desktop == true? "，再按一次退格键还原" : ""}";
  }
  if(condition == "name:"){
    return "搜索name属性${desktop == true? "，再按一次退格键还原" : ""}";
  }
  if(condition == "msg:"){
    return "搜索msg内容${desktop == true? "，再按一次退格键还原" : ""}";
  }
  if(desktop){
    return  "搜索关键词 回车确定";
  }
  return "搜索关键词";
});

/// 搜索框文本变化的状态
final searchTextChangeProvider = StateProvider<String?>((ref) => null);

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
/// 搜索属性(tag name msg)
final propertySearchProvider = StateProvider<String?>((ref) {
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




