// import 'package:sqflite/sqflite.dart' as SQLite;
import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as SQLite;

class AnalyzerDatabase {
  static late SQLite.Database _db;

  static SQLite.Database get db => _db;

  static Future<void> initDataBase(String path) async {
    String mxloggerDatabase = path + "/mxlogger_analyzer.db";
    _db = SQLite.sqlite3.open(mxloggerDatabase);

    _db.execute(
        "CREATE TABLE if not exists  mxlog(id INTEGER PRIMARY KEY AUTOINCREMENT, "
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
  }

  static Future<List<Map<String, Object?>>> selectData(
      {required int page,
      int pageSize = 20,
      String? keyWord,
      List<int>? levels}) async {
    List<Map<String, Object?>> _result = [];
    int start = (page - 1) * pageSize;

    String where = "1=1";

    if (keyWord != null) {
      where = "(msg like'%$keyWord%')";
    }
    if (levels?.isEmpty == false) {
      List<String> _levelSqls = [];
      levels?.forEach((element) {
        _levelSqls.add("level=$element");
      });
      where = where + " and " + "${_levelSqls.join(" or ")}";
    }
    SQLite.ResultSet resultSet =   _db.select("select * from mxlog where $where order by timestamp desc");
    resultSet.forEach((element) {

      Map<String, Object?> map = {
        "name":element["name"],
        "tag":element["tag"],
        "msg":element["msg"],
        "level":element["level"],
        "threadId":element["threadId"],
        "isMainThread":element["isMainThread"],
        "timestamp":element["timestamp"],
        "dateTime":element["dateTime"],
        "createDateTime":element["createDateTime"]
      };
      _result.add(map);
    });

    return _result;
  }

  static int count() {
    SQLite.ResultSet resultSet = _db.select("select count(*) from mxlog");
    int number =  resultSet.first["count(*)"];
    return number;
  }

  static Future<void> deleteData() async {
    _db.execute("delete from mxlog");
    _db.execute("delete from sqlite_sequence where name='mxlog'");

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
      String dateTime =
          DateTime.fromMicrosecondsSinceEpoch(timestamp).toString();
      String nowTime = DateTime.now().toString();
      String sql =
          "insert into mxlog (name,tag,msg,level,threadId,isMainThread,timestamp,dateTime,createDateTime) values(?,?,?,?,?,?,?,?,?)";
      final stmt = _db.prepare(sql);
      stmt.execute([name,tag,msg,level,threadId,isMainThread,timestamp,dateTime,nowTime]);
      stmt.dispose();
    } catch (error) {
      print("数据插入失败:$error");
    }

  }
}
