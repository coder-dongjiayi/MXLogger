// import 'package:sqflite/sqflite.dart' as SQLite;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as SQLite;

class AnalyzerDatabase {
  static late SQLite.Database _db;

  static SQLite.Database get db => _db;

  static String _databaseFile = "";

  /// 数据库文件的完整路径，查询 isolate 需要用它另开一个只读连接
  static String get databaseFile => _databaseFile;

  static void initDataBase(String path) {

    String mxloggerDatabase = path + "/mxlogger_analyzer.db";
    _databaseFile = mxloggerDatabase;
    _db = SQLite.sqlite3.open(mxloggerDatabase);

    _db.execute(
        "CREATE TABLE if not exists  mxlog(id INTEGER PRIMARY KEY AUTOINCREMENT, "
        "name TEXT, "
        "tag TEXT, "
        "msg TEXT, "
        "level INTEGER,"
        "threadId INTEGER,"
        "isMainThread INTEGER, "
        "timestamp INTEGER ," // 日志创建时间戳
        "fileHeader TEXT, " // 文件头
        "dateTime TEXT," // 日志创建时间
        "createDateTime TEXT" // 日志写入到数据库的时间
        ")");

    _ensureIndexes();
  }

  /// 建查询用的索引。
  ///
  /// 没有索引时 `order by timestamp` 每次都要把整表排序，`where level=?`
  /// 也是全表扫描，几十万条日志下一次筛选要一两秒。
  /// 旧版本建的库没有索引，这里用 if not exists 补建，只在第一次打开时有开销。
  static void _ensureIndexes() {
    _db.execute(
        "create index if not exists idx_mxlog_timestamp on mxlog(timestamp)");
    _db.execute("create index if not exists idx_mxlog_level on mxlog(level)");
  }

  /// 拼出查询语句。
  ///
  /// 只负责拼字符串、不碰数据库连接，这样查询可以整段丢进后台 isolate 执行
  /// (见 MXLoggerRepository.fetchLogs)，避免几十万条日志把 UI 线程堵死。
  static String buildQuerySql(
      {String? keyWord,
      String? searchCondition,
      String? order,
      List<int>? levels}) {
    String where = "1=1";

    if (keyWord?.isNotEmpty == true) {
      where = "msg like '%$keyWord%' or tag like '%$keyWord%' or name like '%$keyWord%'";
      // if(condition == null){
      //
      // }else{
      //   List<String> keyWords = keyWord?.trim().split(" ") ?? [];
      //   List<String> conditions = [];
      //   for (var element in keyWords) {
      //     if (element.isNotEmpty == true) {
      //       conditions.add("$condition like'%$element%'");
      //     }
      //   }
      //   where = conditions.join(" or ");
      // }

    }
    if(searchCondition != null){
      where = searchCondition;
    }
    if (levels?.isEmpty == false) {
      List<String> levelSqls = [];
      levels?.forEach((element) {
        levelSqls.add("level=$element");
      });

      /// 等级之间是 or，整体必须括起来，否则 and 的优先级高于 or，
      /// 会变成 (前置条件 and level=0) or level=1，把前置条件漏掉
      where = "($where) and (${levelSqls.join(" or ")})";
    }
    return "select name,tag,msg,level,threadId,isMainThread,timestamp,fileHeader "
        "from mxlog where $where order by timestamp ${order ?? "desc"}";
  }

  static int count() {
    SQLite.ResultSet resultSet = _db.select("select count(*) from mxlog");
    int number = resultSet.first["count(*)"];
    return number;
  }

  static void deleteData() async {
    _db.execute("delete from mxlog");
    _db.execute("delete from sqlite_sequence where name='mxlog'");
  }

  static Future<void> insertData(
      {String? name,
      String? fileHeader,
      String? tag,
      String? msg,
      int? level,
      int? threadId,
      int isMainThread = 0,
      ValueChanged<Map<String, dynamic>>? errorCallback,
      required int timestamp}) async {
    Completer<void> _completer = Completer();
    await Future.delayed(Duration.zero, () {
      String dateTime =
          DateTime.fromMicrosecondsSinceEpoch(timestamp).toString();
      String nowTime = DateTime.now().toString();
      String sql =
          "insert into mxlog (name,tag,msg,level,threadId,isMainThread,timestamp,fileHeader,dateTime,createDateTime)"
          " values(?,?,?,?,?,?,?,?,?,?)";
      final stmt = _db.prepare(sql);
      try {
        stmt.execute([
          name,
          tag,
          msg,
          level,
          threadId,
          isMainThread,
          timestamp,
          fileHeader,
          dateTime,
          nowTime
        ]);
      } catch (error) {
        if (error is SQLite.SqliteException) {
          SQLite.SqliteException e = error;
          errorCallback
              ?.call({"code": e.extendedResultCode, "message": e.message});
        } else {
          errorCallback?.call({"code": "-1", "message": "未知原因:$error"});
        }
      } finally {
        stmt.dispose();
        _completer.complete();
      }
    });

    return _completer.future;
  }
}
