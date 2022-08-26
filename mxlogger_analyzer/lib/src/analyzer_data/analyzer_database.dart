import 'package:sqflite/sqflite.dart' as SQLite;

class AnalyzerDatabase {
  static late SQLite.Database _db;

  static Future<void> initDataBase() async {
    String database = await SQLite.getDatabasesPath();

    String mxloggerDatabase = database + "/mxlogger_analyzer.db";

    _db = await SQLite.openDatabase(mxloggerDatabase, version: 1,
        onCreate: (db, version) {
      return db
          .execute("CREATE TABLE mxlog(id INTEGER PRIMARY KEY AUTOINCREMENT, "
              "name TEXT, "
              "tag TEXT, "
              "msg TEXT, "
              "level INTEGER,"
              "threadId INTEGER,"
              "isMainThread INTEGER, "
              "timestamp INTEGER UNIQUE," // 日志创建时间戳
              "dateTime TEXT," // 日志创建时间
              "createDateTime TEXT" // 日志写入到数据库的时间
              ")");
    });
  }

  static Future<List<Map<String, Object?>>> selectData(
      {required int page,int pageSize = 20,String? keyWord}) async {
    int start = (page - 1) * pageSize;

    List<Map<String, Object?>> result =
        await _db.rawQuery("select * from mxlog order by timestamp desc  limit $start,$pageSize");
    return result;
  }

  static Future<void> insertData(
      {String? name,
      String? tag,
      String? msg,
      int? level,
      int? threadId,
      int isMainThread = 0,
      required int timestamp}) async {
    try {
      _db.insert("mxlog", {
        "name": name,
        "tag": tag,
        "msg": msg,
        "level": level,
        "dateTime": DateTime.fromMicrosecondsSinceEpoch(timestamp).toString(),
        "timestamp": timestamp,
        "threadId": threadId,
        "isMainThread": isMainThread,
        "createDateTime": DateTime.now().toString()
      });
    } catch (error) {
      print("插入失败:$error");
    }
  }
}
