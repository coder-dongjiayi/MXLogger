
import 'package:sqflite/sqflite.dart' as SQLite;

class AnalyzerDatabase {
  static late SQLite.Database _db;

  static void initDataBase() async {
    String database = await SQLite.getDatabasesPath();

    String mxloggerDatabase = database + "/mxlogger_analyzer.db";

    _db = await SQLite.openDatabase(mxloggerDatabase, version: 1,
        onCreate: (db, version) {
      return db.execute(
          "CREATE TABLE mxlogs(id INTEGER PRIMARY KEY AUTOINCREMENT, "
              "name TEXT, "
              "tag TEXT, "
              "msg TEXT, "
              "level INTEGER,"
              "threadId INTEGER,"
              "isMainThread INTEGER, "
              "timestamp INTEGER,"
              "dateTime TEXT"
              ")");
    });
  }
}
