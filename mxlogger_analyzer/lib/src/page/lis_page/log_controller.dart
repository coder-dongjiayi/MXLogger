import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import '../detail_page/view/async_future_loader.dart';
import 'log_model.dart';

class LogController extends ChangeNotifier {

   AsyncController asyncController = AsyncController();

  Future<void> insertData() async{

  }

  Future<List<LogModel>> loadData() async {
    List<Map<String, Object?>> list = await AnalyzerDatabase.selectData();
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
