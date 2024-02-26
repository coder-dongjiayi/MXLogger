import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analyzer_data/analyzer_binary.dart';
import '../analyzer_data/analyzer_database.dart';
import '../screen/home_screen/log_model.dart';

final mxloggerRepository = Provider.autoDispose((ref) => MXLoggerRepository());

class MXLoggerRepository {
  /// 请求数据库中的日志数据
  /// page 当前页数 不传则请求全部
  /// keyWord 搜索关键词
  /// levels 需要过滤的日志等级
  Future<List<LogModel>> fetchLogs(
      {String? condition, String? searchCondition, int? page, String? keyWord, String? order, List<int>? levels}) async {
    List<Map<String, Object?>> list = await AnalyzerDatabase.selectData(
        page: page ?? 1, order: order, searchCondition: searchCondition, keyWord: keyWord, levels: levels);
    List<LogModel> source = _transformLogModel(list);
    return source;
  }

  /// 清空数据
  void deleteData() {
    return AnalyzerDatabase.deleteData();
  }

  /// 查询数据库总条数
  int fetchLogCount() {
    return AnalyzerDatabase.count();
  }


  /// 导入二进制数据到数据库
  void importBytes(
      {required List<Uint8List> binaryData,
        required String databasePath,
      required StreamController<Map<String, dynamic>?> streamController,
      String? cryptKey,
      String? cryptIv}) {
    AnalyzerBinary.loadBinaryData(
        binaryList: binaryData,
        databasePath: databasePath,
        cryptKey: cryptKey,
        iv: cryptIv,
        onStartCallback: () {
          streamController.add({"status": 0, "message": "正在导入数据"});
        },
        onErrorCallback: (String errorMsg) {
          streamController.add({"status": 4, "message": errorMsg});
        },
        onProgressCallback: (int total, int current, int index) {
          double progress = current.toDouble() / total.toDouble();
          if (total == current) progress = 1.0;

         String progressMessage =  (progress * 100).toStringAsFixed(1);
          streamController.add({
            "status": 1,
            "progress": progress,
            "message": "正在解析数据:$progressMessage%"
          });
        },
        onEndCallback: (success, repeat, field) {
          if (field == 0) {
            streamController.add(
                {"status": 2, "message": "共$success条数据导入成功", "repeat": repeat});
          } else {
            streamController
                .add({"status": 3, "message": "$success条数据导入成功，$field条数据导入失败"});
          }
        });
  }

  /// map 转化model
  List<LogModel> _transformLogModel(List<Map<String, Object?>> list) {
    List<LogModel> _source = [];
    list.forEach((element) {
      int level = element["level"] as int;
      int timestamp = element["timestamp"] as int;
      String? name = element["name"] as String?;
      String? tag = element["tag"] as String?;
      String? msg = element["msg"] as String?;
      String? fileHeader = element["fileHeader"] as String?;
      int? threadId = element["threadId"] as int?;
      int? mainThreadId = element["isMainThread"] as int?;
      LogModel model = LogModel(
          name: name,
          tag: tag,
          msg: msg,
          threadId: threadId,
          isMainThread: mainThreadId,
          level: level,
          fileHeader: fileHeader,
          timestamp: timestamp);
      _source.add(model);
    });
    return _source;
  }
}
