import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' as SQLite;

import '../analyzer_data/analyzer_binary.dart';
import '../analyzer_data/analyzer_database.dart';
import '../screen/home_screen/log_model.dart';

final mxloggerRepository = Provider.autoDispose((ref) => MXLoggerRepository());

class MXLoggerRepository {
  /// 请求数据库中的日志数据
  /// page 当前页数 不传则请求全部
  /// keyWord 搜索关键词
  /// levels 需要过滤的日志等级
  ///
  /// 查询和 LogModel 构造整段放在后台 isolate 里跑，主 isolate 全程不阻塞，
  /// 加载指示器才转得起来。Isolate.run 结束时通过 Isolate.exit 把结果所在的
  /// 堆直接移交给主 isolate，不是逐个对象深拷贝，所以回传几乎没有开销。
  Future<List<LogModel>> fetchLogs(
      {String? searchCondition,
      int? page,
      String? keyWord,
      String? order,
      List<int>? levels}) {
    final String databaseFile = AnalyzerDatabase.databaseFile;
    if (databaseFile.isEmpty) return Future.value(const []);

    final String sql = AnalyzerDatabase.buildQuerySql(
        order: order,
        searchCondition: searchCondition,
        keyWord: keyWord,
        levels: levels);

    return Isolate.run(() => _queryLogs(databaseFile, sql));
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

}

/// 在后台 isolate 中执行：另开一个只读连接查询并直接构造 LogModel。
///
/// sqlite3 的连接不能跨 isolate 共享，这里按文件路径重新打开；只读模式下
/// 不会和主 isolate 的写连接冲突。
List<LogModel> _queryLogs(String databaseFile, String sql) {
  final SQLite.Database db =
      SQLite.sqlite3.open(databaseFile, mode: SQLite.OpenMode.readOnly);
  try {
    final SQLite.ResultSet resultSet = db.select(sql);
    final List<LogModel> source = [];
    for (final SQLite.Row row in resultSet) {
      source.add(LogModel(
        name: row["name"] as String?,
        tag: row["tag"] as String?,
        msg: row["msg"] as String?,
        threadId: row["threadId"] as int?,
        isMainThread: row["isMainThread"] as int?,
        level: row["level"] as int,
        fileHeader: row["fileHeader"] as String?,
        timestamp: row["timestamp"] as int,
      ));
    }
    return source;
  } finally {
    db.dispose();
  }
}
