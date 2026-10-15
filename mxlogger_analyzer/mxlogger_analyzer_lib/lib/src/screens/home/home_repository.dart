import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/platform/repository_files_unsupported.dart'
    if (dart.library.io) 'package:mxlogger_analyzer_lib/src/screens/home/platform/repository_files_native.dart'
    as platform;
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_file_name.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 单个文件的解析产物；result 为 null 表示该文件解析失败。
typedef ParsedFile = ({String name, MxParseResult? result});

/// 已读入内存、等待解析的单个文件。
typedef LoadedFile = ({String name, Uint8List bytes});

/// 数据库连接的获取方式（由 MXStore 注入，测试可给内存/临时目录库）。
typedef AnalyzerDatabaseLoader = Future<AnalyzerDatabase> Function();

/// 某条日志在**全部日志**（忽略筛选）里的前后上下文。
/// [older] / [newer] 均按「离锚点由近到远」排列；
/// [olderCount] 为全局比锚点更早的条数，[total] 为全局总条数，二者用于算「第 N 条 / 共 M 条」。
typedef LogContext = ({
  List<LogModel> older,
  List<LogModel> newer,
  int olderCount,
  int total,
});

/// 日志数据层：解析、替换入库、查询、统计，UI 不直接触达数据库。
class HomeRepository {
  HomeRepository(this._loadDatabase);

  final AnalyzerDatabaseLoader _loadDatabase;

  static const String _metaFileName = "fileName";

  Future<AnalyzerDatabase> get _database => _loadDatabase();

  /// 落库操作的串行队列尾部
  Future<void> _gate = Future<void>.value();

  /// 串行闸门：所有触达数据库的操作排成一条队列，前一个跑完才放行下一个。
  ///
  /// 写库会在批次之间让出事件循环（见 [AnalyzerDatabase.insertRecordsWithProgress]），
  /// 若此期间放行查询就会读到「导入到一半」的数据，放行 [clearAll] 更会把已提交的
  /// 批次删掉、让最终数据静默错乱。事务边界解决不了这类交错——只有把整次导入
  /// 当成不可分割的临界区才行，而这个保证必须落在数据层，不能依赖 UI 层
  /// isRunning 之类的约定（那些约定散落在各处，新增一次刷新就会破功）。
  Future<T> _serial<T>(Future<T> Function() action) {
    final Future<T> result = _gate.then((_) => action());
    // 失败不能污染队列：错误照常抛给调用方，队列自身吞掉后继续放行
    _gate = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<int>> fileSizes(List<String> paths) => platform.fileSizes(paths);

  Future<List<LoadedFile>> readFiles({
    required List<String> paths,
    required List<int> sizes,
    void Function(double)? onProgress,
  }) => platform.readFiles(paths: paths, sizes: sizes, onProgress: onProgress);

  Future<List<ParsedFile>> parseFiles({
    required List<LoadedFile> files,
    List<MxCryptPair> cryptPairs = const [],
    void Function(int, double)? onProgress,
  }) => platform.parseFiles(
    files: files,
    cryptPairs: cryptPairs,
    onProgress: onProgress,
  );

  Future<List<String>> listLogFiles(String directory) =>
      platform.listLogFiles(directory);

  /// Hosts may override the entire import pipeline to keep large parsed results
  /// in their background worker. Native hosts retain the virtual IO hooks above.
  Future<void> importFiles({
    required List<String> paths,
    List<MxCryptPair> cryptPairs = const [],
    bool clearExisting = true,
    void Function(ImportProgress)? onProgress,
  }) async {
    List<int> sizes;
    List<LoadedFile> files;
    List<ParsedFile> parsed;
    String label = '';
    void report(ImportStep step, double percent) => onProgress?.call(
      ImportProgress(
        step: step,
        percent: percent.clamp(0, 100).round(),
        fileLabel: label,
      ),
    );
    try {
      sizes = await fileSizes(paths);
      final total = sizes.fold(0, (int sum, int size) => sum + size);
      final name = mxFileName(paths.first);
      label =
          '${paths.length > 1 ? "$name +${paths.length - 1}" : name}  (${mxFmtBytes(total)})';
      report(ImportStep.reading, 0);
      files = await readFiles(
        paths: paths,
        sizes: sizes,
        onProgress: (fraction) => report(ImportStep.reading, 8 * fraction),
      );
      report(ImportStep.decrypting, 8);
      parsed = await parseFiles(
        files: files,
        cryptPairs: cryptPairs,
        onProgress: (index, fraction) {
          if (total <= 0) return;
          final before = sizes
              .take(index)
              .fold(0, (int sum, int size) => sum + size);
          report(
            ImportStep.decrypting,
            8 + 70 * (before + fraction * sizes[index]) / total,
          );
        },
      );
    } catch (_) {
      throw const ImportFailure(ImportError.readFailed);
    }
    final usable = parsed
        .where((file) => file.result?.records.isNotEmpty ?? false)
        .toList();
    if (usable.isEmpty) {
      final suspect = parsed.any(
        (file) => file.result == null || file.result!.errorCount > 0,
      );
      throw ImportFailure(
        suspect ? ImportError.parseFailed : ImportError.noRecords,
      );
    }
    report(ImportStep.indexing, 78);
    try {
      final first = usable.first.name;
      await replaceWith(
        results: usable.map((file) => file.result!).toList(),
        fileName: usable.length > 1 ? '$first +${usable.length - 1}' : first,
        clearExisting: clearExisting,
        onProgress: (fraction) =>
            report(ImportStep.indexing, 78 + 21 * fraction),
      );
    } catch (_) {
      throw const ImportFailure(ImportError.writeFailed);
    }
    report(ImportStep.done, 100);
  }

  /// 解析成功后写入数据库，[onProgress] 回报写库真实进度（0.0-1.0）。
  /// [clearExisting] 为 true 时先清空旧数据（替换），否则追加合并
  /// （timestamp UNIQUE + INSERT OR IGNORE 天然去重）。
  Future<void> replaceWith({
    required List<MxParseResult> results,
    required String fileName,
    bool clearExisting = true,
    void Function(double fraction)? onProgress,
  }) => _serial(
    () => _replaceWith(
      results: results,
      fileName: fileName,
      clearExisting: clearExisting,
      onProgress: onProgress,
    ),
  );

  Future<void> _replaceWith({
    required List<MxParseResult> results,
    required String fileName,
    bool clearExisting = true,
    void Function(double fraction)? onProgress,
  }) async {
    final AnalyzerDatabase database = await _database;
    if (clearExisting) database.clear();
    final int total = results.fold(
      0,
      (int sum, MxParseResult result) => sum + result.records.length,
    );
    int done = 0;
    for (final MxParseResult result in results) {
      await database.insertRecordsWithProgress(
        result.records,
        fileHeader: result.fileHeader,
        onProgress: (int processed, int recordTotal) {
          if (total > 0) onProgress?.call((done + processed) / total);
        },
      );
      done = done + result.records.length;
    }
    database.setMeta(_metaFileName, fileName);
    onProgress?.call(1);
  }

  /// 清空全部日志与元信息（「清除数据」功能）。
  Future<void> clearAll() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    database.clear();
  });

  /// [limit] 为 null 时返回全部（导出分享用），分页查询传 limit + offset。
  Future<List<LogModel>> fetchLogs(
    LogFilterState filter, {
    int? limit,
    int? offset,
  }) => _serial(() async {
    final AnalyzerDatabase database = await _database;
    final List<Map<String, Object?>> rows = database.selectLogs(
      filter.toQuery(limit: limit, offset: offset),
    );
    return rows.map(LogModel.fromJson).toList();
  });

  /// 当前过滤条件下的总条数（分页「共 N 条」与 hasMore 判断用）。
  Future<int> fetchLogsCount(LogFilterState filter) => _serial(() async {
    final AnalyzerDatabase database = await _database;
    return database.countLogs(filter.toQuery());
  });

  /// 锚点日志前后各 [limit] 条全局上下文（不受当前筛选影响），一次串行查询内取齐，
  /// 保证条数与位置出自同一份数据快照。
  ///
  /// 日志以 timestamp（微秒）为唯一标识，所以「更早 / 更新」直接按 timestamp
  /// 开区间取，复用 [AnalyzerDatabase.selectLogs] 的时间范围条件即可命中 timestamp 索引。
  Future<LogContext> fetchContext(LogModel anchor, {int limit = 20}) =>
      _serial(() async {
        final AnalyzerDatabase database = await _database;
        return (
          older: _olderThan(database, anchor.timestamp, limit),
          newer: _newerThan(database, anchor.timestamp, limit),
          olderCount: database.countLogs(LogQuery(toUs: anchor.timestamp - 1)),
          total: database.count(),
        );
      });

  /// 比 [timestampUs] 更早的 [limit] 条（离它最近的在前），供上下文面板继续往前翻。
  Future<List<LogModel>> fetchOlderThan(int timestampUs, {int limit = 20}) =>
      _serial(() async => _olderThan(await _database, timestampUs, limit));

  /// 比 [timestampUs] 更新的 [limit] 条（离它最近的在前），供上下文面板继续往后翻。
  Future<List<LogModel>> fetchNewerThan(int timestampUs, {int limit = 20}) =>
      _serial(() async => _newerThan(await _database, timestampUs, limit));

  List<LogModel> _olderThan(
    AnalyzerDatabase database,
    int timestampUs,
    int limit,
  ) {
    final List<Map<String, Object?>> rows = database.selectLogs(
      LogQuery(toUs: timestampUs - 1, ascending: false, limit: limit),
    );
    return rows.map(LogModel.fromJson).toList();
  }

  List<LogModel> _newerThan(
    AnalyzerDatabase database,
    int timestampUs,
    int limit,
  ) {
    final List<Map<String, Object?>> rows = database.selectLogs(
      LogQuery(fromUs: timestampUs + 1, ascending: true, limit: limit),
    );
    return rows.map(LogModel.fromJson).toList();
  }

  Future<Map<int, int>> fetchLevelCounts() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    return database.levelCounts();
  });

  /// 搜索联想用：全部 tag（分词去重）
  Future<List<String>> fetchTagOptions() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    return database.distinctTags();
  });

  /// 搜索联想用：全部 name（去重）
  Future<List<String>> fetchNameOptions() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    return database.distinctNames();
  });

  Future<int> fetchCount() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    return database.count();
  });

  Future<HeaderInfo> fetchHeaderInfo() => _serial(() async {
    final AnalyzerDatabase database = await _database;
    final bounds = database.timeBounds();
    return HeaderInfo(
      total: database.count(),
      minUs: bounds?.minUs,
      maxUs: bounds?.maxUs,
      fileName: database.getMeta(_metaFileName) ?? "",
      header: HeaderInfo.parseHeader(database.firstFileHeader()),
    );
  });
}
