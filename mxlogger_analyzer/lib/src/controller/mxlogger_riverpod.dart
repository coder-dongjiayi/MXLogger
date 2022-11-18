import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_repository.dart';

///  查询所有日志数据
final logPagesProvider = FutureProvider.autoDispose((ref){

  final repository = ref.watch(mxloggerRepositoryProvider);
  final kw = ref.watch(searchKeywordProvider);

  final logResponse = repository.fetchLogs(page: null,keyWord: kw,levels: null);

  return logResponse;
});



final searchKeywordProvider = StateProvider.autoDispose<String?>((ref){
 return null;
});

