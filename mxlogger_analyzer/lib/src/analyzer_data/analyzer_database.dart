import 'package:sqflite/sqflite.dart' as SQLite;

class AnalyzerDatabase {
  static late SQLite.Database _db;

  static Future<void> initDataBase() async {
    String database = await SQLite.getDatabasesPath();

    String mxloggerDatabase = database + "/mxlogger_analyzer.db";

    _db = await SQLite.openDatabase(mxloggerDatabase, version: 1,
        onCreate: (db, version) {
      return db.execute("CREATE TABLE mxlog(id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "name TEXT, "
          "tag TEXT, "
          "msg TEXT, "
          "level INTEGER,"
          "threadId INTEGER,"
          "isMainThread INTEGER, "
          "timestamp INTEGER UNIQUE,"
          "dateTime TEXT"
          ")");
    });


  }


  static Future<int> insertData(
      {String? name,
      String? tag,
      String? msg,
      int? level,
      int? threadId,
      int isMainThread = 0,
      required int timestamp}) async {

    int result = await _db.rawInsert(
      "INSERT OR IGNORE INTO mxlog"
      "(name,tag,msg,level,threadId,isMainThread,timestamp,dateTime)"
      " VALUES('$name','$tag','$msg',$level,999,$isMainThread,$timestamp,'${DateTime.now()}')",
    );

    if(result > 0){
      print("插入成功");
    }
    return result;
  }
}
