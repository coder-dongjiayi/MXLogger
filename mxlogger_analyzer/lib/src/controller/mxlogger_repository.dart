import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analyzer_data/analyzer_database.dart';
import '../page/lis_page/log_model.dart';



final mxloggerRepositoryProvider = Provider.autoDispose((ref) => MXLoggerRepository());

class MXLoggerRepository{

  /// 请求数据库中的日志数据
  /// page 当前页数 不传则请求全部
  /// keyWord 搜索关键词
  /// levels 需要过滤的日志等级
  Future<List<LogModel>> fetchLogs({int? page,String? keyWord,
    List<int>? levels}) async{
    List<Map<String, Object?>> list = await AnalyzerDatabase.selectData(page: page ?? 1,keyWord: keyWord,levels: levels);
    List<LogModel> source = _transformLogModel(list);
    return source;
  }


  /// map 转化model
  List<LogModel> _transformLogModel( List<Map<String, Object?>> list){
    List<LogModel> _source = [];
    list.forEach((element) {
      int level = element["level"] as int;
      int timestamp = element["timestamp"] as int;
      String? name = element["name"] as String?;
      String? tag = element["tag"] as String?;
      String? msg = element["msg"] as String?;
      int? threadId = element["threadId"] as int?;
      int? mainThreadId = element["isMainThread"] as int?;
      LogModel model = LogModel(
          name: name,
          tag: tag,
          msg: msg,
          threadId: threadId,
          isMainThread: mainThreadId,
          level: level,
          timestamp: timestamp);
      _source.add(model);
    });
    return _source;
  }
}