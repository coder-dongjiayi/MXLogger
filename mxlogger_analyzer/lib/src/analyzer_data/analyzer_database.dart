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
      {required int page, int pageSize = 20, String? keyWord,List<int>? levels}) async {

    int start = (page - 1) * pageSize;

    String where = "1=1";

    if(keyWord!= null){
      where = "(msg like'%$keyWord%')";
    }
   if(levels?.isEmpty == false){
     List<String> _levelSqls = [];
     levels?.forEach((element) {
       _levelSqls.add("level=$element");

     });
     where = where + " and " + "${_levelSqls.join(" or ")}";
   }
    // List<Map<String, Object?>> result = await _db.query("mxlog",
    //     orderBy: "timestamp desc",limit: pageSize,offset: start,where: where);

    List<Map<String, Object?>> result = await _db.query("mxlog",
        orderBy: "timestamp desc",where: where);
    return result;
  }
 static Future<void> deleteData() async{
   await _db.delete("mxlog");
   await _db.delete("sqlite_sequence",where: " name = 'mxlog'");
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
