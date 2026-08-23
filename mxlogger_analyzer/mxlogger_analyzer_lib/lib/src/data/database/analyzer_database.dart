import 'package:sqlite3/sqlite3.dart';

import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

/// 批量入库结果：成功条数 / 因 timestamp 重复被忽略的条数。
typedef InsertSummary = ({int inserted, int duplicated});

/// 搜索范围（对齐设计稿 scope：全部 / 内容 / Tag / Name）。
enum MxSearchScope { all, content, tag, name }

/// 日志查询条件。
class LogQuery {
  const LogQuery({
    this.keyword,
    this.scope = MxSearchScope.all,
    this.levels,
    this.tags,
    this.names,
    this.fromUs,
    this.toUs,
    this.ascending = true,
    this.limit,
    this.offset,
  });

  final String? keyword;
  final MxSearchScope scope;
  final List<int>? levels;

  /// #tag 多选过滤（tag 列按逗号/空格分词匹配；多值取「或」）
  final List<String>? tags;

  /// @name 多选过滤（多值取「或」）
  final List<String>? names;

  /// 时间范围（微秒时间戳，闭区间）
  final int? fromUs;
  final int? toUs;
  final bool ascending;

  /// 分页：limit 为 null 时返回全部（offset 仅在 limit 非空时生效）
  final int? limit;
  final int? offset;
}

/// sqlite 封装：日志的唯一持久化入口。
/// 以 timestamp（微秒）作为日志唯一标识，重复导入自动忽略。
class AnalyzerDatabase {
  AnalyzerDatabase(String directory) : _path = "$directory/mxlogger_analyzer.db";

  final String _path;
  Database? _db;

  Database get _database {
    final Database? db = _db;
    if (db == null) throw StateError("database is not opened");
    return db;
  }

  void open() {
    if (_db != null) return;
    final Database db = sqlite3.open(_path);
    db.execute("""
      CREATE TABLE IF NOT EXISTS mxlog(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        tag TEXT,
        msg TEXT,
        level INTEGER,
        threadId INTEGER,
        isMainThread INTEGER,
        timestamp INTEGER UNIQUE,
        fileHeader TEXT
      )
    """);
    db.execute("CREATE INDEX IF NOT EXISTS idx_mxlog_level ON mxlog(level)");
    db.execute("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT)");
    _db = db;
  }

  /// 事务内批量插入，timestamp 冲突走 OR IGNORE 并计入重复数。
  InsertSummary insertRecords(List<LogRecord> records, {String? fileHeader}) {
    final Database db = _database;
    final int before = _totalChanges(db);
    final PreparedStatement stmt = db.prepare(
      "INSERT OR IGNORE INTO mxlog (name,tag,msg,level,threadId,isMainThread,timestamp,fileHeader)"
      " VALUES (?,?,?,?,?,?,?,?)",
    );
    db.execute("BEGIN");
    try {
      for (final LogRecord record in records) {
        stmt.execute([
          record.name,
          record.tag,
          record.msg,
          record.level,
          record.threadId,
          record.isMainThread,
          record.timestamp,
          fileHeader,
        ]);
      }
      db.execute("COMMIT");
    } catch (_) {
      db.execute("ROLLBACK");
      rethrow;
    } finally {
      stmt.dispose();
    }
    final int inserted = _totalChanges(db) - before;
    return (inserted: inserted, duplicated: records.length - inserted);
  }

  /// 事务内分批插入：每批后让出事件循环并回报真实进度（processed/total），
  /// 大文件写库时 UI 仍可刷新 loading。
  Future<InsertSummary> insertRecordsWithProgress(
    List<LogRecord> records, {
    String? fileHeader,
    int batchSize = 800,
    void Function(int processed, int total)? onProgress,
  }) async {
    final Database db = _database;
    final int before = _totalChanges(db);
    final PreparedStatement stmt = db.prepare(
      "INSERT OR IGNORE INTO mxlog (name,tag,msg,level,threadId,isMainThread,timestamp,fileHeader)"
      " VALUES (?,?,?,?,?,?,?,?)",
    );
    db.execute("BEGIN");
    try {
      for (int i = 0; i < records.length; i++) {
        final LogRecord record = records[i];
        stmt.execute([
          record.name,
          record.tag,
          record.msg,
          record.level,
          record.threadId,
          record.isMainThread,
          record.timestamp,
          fileHeader,
        ]);
        if ((i + 1) % batchSize == 0) {
          onProgress?.call(i + 1, records.length);
          await Future<void>.delayed(Duration.zero);
        }
      }
      db.execute("COMMIT");
    } catch (_) {
      db.execute("ROLLBACK");
      rethrow;
    } finally {
      stmt.dispose();
    }
    onProgress?.call(records.length, records.length);
    final int inserted = _totalChanges(db) - before;
    return (inserted: inserted, duplicated: records.length - inserted);
  }

  /// 关键词（按 scope 限定范围）+ 等级 + tag/name 精确 + 时间范围，全部参数化防注入。
  List<Map<String, Object?>> selectLogs(LogQuery query) {
    final ({String where, List<Object?> args}) clause = _whereClause(query);
    final String order = query.ascending ? "ASC" : "DESC";
    String sql = "SELECT * FROM mxlog WHERE ${clause.where}"
        " ORDER BY timestamp $order, id $order";
    final List<Object?> args = [...clause.args];
    if (query.limit != null) {
      sql += " LIMIT ? OFFSET ?";
      args.addAll([query.limit, query.offset ?? 0]);
    }
    final ResultSet resultSet = _database.select(sql, args);
    return resultSet.map((Row row) => Map<String, Object?>.from(row)).toList();
  }

  /// 同一组过滤条件下的总条数（分页展示「共 N 条」用，忽略 limit/offset）。
  int countLogs(LogQuery query) {
    final ({String where, List<Object?> args}) clause = _whereClause(query);
    final ResultSet resultSet = _database.select(
      "SELECT COUNT(*) AS c FROM mxlog WHERE ${clause.where}",
      clause.args,
    );
    return resultSet.first["c"] as int? ?? 0;
  }

  ({String where, List<Object?> args}) _whereClause(LogQuery query) {
    final List<String> conditions = [];
    final List<Object?> args = [];

    final String? keyword = query.keyword?.trim();
    if (keyword != null && keyword.isNotEmpty) {
      final String pattern = "%${_escapeLike(keyword)}%";
      const String like = "LIKE ? ESCAPE '\\'";
      switch (query.scope) {
        case MxSearchScope.content:
          conditions.add("msg $like");
          args.add(pattern);
        case MxSearchScope.tag:
          conditions.add("tag $like");
          args.add(pattern);
        case MxSearchScope.name:
          conditions.add("name $like");
          args.add(pattern);
        case MxSearchScope.all:
          conditions.add("(msg $like OR tag $like OR name $like)");
          args.addAll([pattern, pattern, pattern]);
      }
    }

    final List<int>? levels = query.levels;
    if (levels != null && levels.isNotEmpty) {
      final String placeholders = List.filled(levels.length, "?").join(",");
      conditions.add("level IN ($placeholders)");
      args.addAll(levels);
    }

    // tag 列可存多个逗号/空格分隔的 tag，逗号归一为空格后按分词精确匹配；
    // 多个选中 tag 之间取「或」
    final List<String> tags =
        query.tags?.where((String t) => t.isNotEmpty).toList() ?? const [];
    if (tags.isNotEmpty) {
      final List<String> ors = [];
      for (final String tag in tags) {
        ors.add("instr(' ' || replace(COALESCE(tag,''), ',', ' ') || ' ', ?) > 0");
        args.add(" $tag ");
      }
      conditions.add("(${ors.join(" OR ")})");
    }

    // 多个选中 name 之间取「或」
    final List<String> names =
        query.names?.where((String n) => n.isNotEmpty).toList() ?? const [];
    if (names.isNotEmpty) {
      final String placeholders = List.filled(names.length, "?").join(",");
      conditions.add("name IN ($placeholders)");
      args.addAll(names);
    }

    if (query.fromUs != null) {
      conditions.add("timestamp >= ?");
      args.add(query.fromUs);
    }
    if (query.toUs != null) {
      conditions.add("timestamp <= ?");
      args.add(query.toUs);
    }

    final String where = conditions.isEmpty ? "1=1" : conditions.join(" AND ");
    return (where: where, args: args);
  }

  int count() {
    final ResultSet resultSet = _database.select("SELECT COUNT(*) AS c FROM mxlog");
    return resultSet.first["c"] as int? ?? 0;
  }

  /// 各等级条数统计，用于分布条与过滤 chip。
  Map<int, int> levelCounts() {
    final ResultSet resultSet =
        _database.select("SELECT level, COUNT(*) AS c FROM mxlog GROUP BY level");
    final Map<int, int> counts = {};
    for (final Row row in resultSet) {
      counts[row["level"] as int? ?? 0] = row["c"] as int? ?? 0;
    }
    return counts;
  }

  /// 所有出现过的 tag（tag 列按逗号/空格分词后去重、升序），供搜索联想。
  List<String> distinctTags() {
    final ResultSet resultSet = _database
        .select("SELECT tag FROM mxlog WHERE tag IS NOT NULL AND tag != ''");
    final Set<String> tags = {};
    for (final Row row in resultSet) {
      final String raw = (row["tag"] as String?) ?? "";
      for (final String tag in raw.split(RegExp(r"[,\s]+"))) {
        if (tag.isNotEmpty) tags.add(tag);
      }
    }
    final List<String> list = tags.toList()..sort();
    return list;
  }

  /// 所有出现过的 name（去重、升序），供搜索联想。
  List<String> distinctNames() {
    final ResultSet resultSet = _database.select(
      "SELECT DISTINCT name FROM mxlog WHERE name IS NOT NULL AND name != '' ORDER BY name",
    );
    return resultSet.map((Row row) => row["name"] as String).toList();
  }

  /// 起始/结束时间（微秒），空库返回 null。
  ({int minUs, int maxUs})? timeBounds() {
    final ResultSet resultSet =
        _database.select("SELECT MIN(timestamp) AS a, MAX(timestamp) AS b FROM mxlog");
    final Row row = resultSet.first;
    final int? min = row["a"] as int?;
    final int? max = row["b"] as int?;
    if (min == null || max == null) return null;
    return (minUs: min, maxUs: max);
  }

  /// 首个非空文件头（写入端环境信息）。
  String? firstFileHeader() {
    final ResultSet resultSet = _database.select(
        "SELECT fileHeader FROM mxlog WHERE fileHeader IS NOT NULL AND fileHeader != '' LIMIT 1");
    if (resultSet.isEmpty) return null;
    return resultSet.first["fileHeader"] as String?;
  }

  String? getMeta(String key) {
    final ResultSet resultSet =
        _database.select("SELECT value FROM meta WHERE key = ?", [key]);
    if (resultSet.isEmpty) return null;
    return resultSet.first["value"] as String?;
  }

  void setMeta(String key, String value) {
    _database.execute(
      "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
      [key, value],
    );
  }

  void clear() {
    final Database db = _database;
    db.execute("DELETE FROM mxlog");
    db.execute("DELETE FROM sqlite_sequence WHERE name='mxlog'");
    db.execute("DELETE FROM meta");
  }

  void dispose() {
    _db?.dispose();
    _db = null;
  }

  int _totalChanges(Database db) {
    final ResultSet resultSet = db.select("SELECT total_changes() AS c");
    return resultSet.first["c"] as int? ?? 0;
  }

  /// LIKE 通配符转义，保证用户输入的 % _ \ 按字面匹配
  String _escapeLike(String input) {
    return input
        .replaceAll("\\", "\\\\")
        .replaceAll("%", "\\%")
        .replaceAll("_", "\\_");
  }
}
