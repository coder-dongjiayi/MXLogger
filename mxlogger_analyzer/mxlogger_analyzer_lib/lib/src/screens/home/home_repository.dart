import 'dart:io';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/parse_isolate.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 单个文件的解析产物；result 为 null 表示该文件解析失败。
typedef ParsedFile = ({String name, MxParseResult? result});

/// 已读入内存、等待解析的单个文件。
typedef LoadedFile = ({String name, Uint8List bytes});

/// 数据库连接的获取方式（由 MXStore 注入，测试可给内存/临时目录库）。
typedef AnalyzerDatabaseLoader = Future<AnalyzerDatabase> Function();

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

  /// 各文件字节大小（进度权重与文件标签用）。IO 失败抛出。
  Future<List<int>> fileSizes(List<String> paths) async {
    final List<int> sizes = [];
    for (final String path in paths) {
      sizes.add(await File(path).length());
    }
    return sizes;
  }

  /// 读取文件字节，按**累计已读字节**回报真实进度（0.0-1.0）。
  ///
  /// 分块读而不是一次 `readAsBytes`：单个大文件光读就要几百毫秒
  /// （127 MiB 实测约 350ms），整块读期间无从回报，进度条只能僵在起点。
  /// 读取与解析拆成两步也是为此——原先 readAsBytes 藏在 [parseFiles] 内部，
  /// 那段耗时被算进了解析阶段的开头且不回报，表现为进度条卡在解析起点不动。
  /// IO 失败直接抛出，由上层归类为读取错误。
  Future<List<LoadedFile>> readFiles({
    required List<String> paths,
    required List<int> sizes,
    void Function(double fraction)? onProgress,
  }) async {
    const int chunkSize = 4 * 1024 * 1024;
    final int totalBytes = sizes.fold(0, (int sum, int size) => sum + size);
    final List<LoadedFile> files = [];
    int done = 0;
    for (int i = 0; i < paths.length; i++) {
      final String path = paths[i];
      final int size = sizes[i];
      final Uint8List bytes = Uint8List(size);
      final RandomAccessFile handle = await File(path).open();
      int offset = 0;
      try {
        while (offset < size) {
          final int end = offset + chunkSize < size ? offset + chunkSize : size;
          final int read = await handle.readInto(bytes, offset, end);
          // 读到 0 说明文件在 stat 之后被截短了，按实际读到的长度收尾
          if (read <= 0) break;
          offset = offset + read;
          done = done + read;
          if (totalBytes > 0) onProgress?.call(done / totalBytes);
        }
      } finally {
        await handle.close();
      }
      files.add((
        name: path.split(Platform.pathSeparator).last,
        // 文件被截短时不能把尾部的零字节交给解析器
        bytes: offset == size ? bytes : Uint8List.sublistView(bytes, 0, offset),
      ));
    }
    if (totalBytes <= 0) onProgress?.call(1);
    return files;
  }

  /// 解析已读入内存的文件（不落库）：.mx 走二进制（解密+flatbuffer），
  /// 其余扩展名尝试 JSON-lines。解析在独立 isolate 内执行，
  /// [cryptPairs] 为多组解密参数，按顺序依次尝试（第一组解不开换下一组）。
  /// [onProgress] 回报（文件下标, 该文件内 0.0-1.0 真实进度）。
  ///
  /// 注意：字节所有权会转移给解析 isolate（见 [ParseIsolate.run]），
  /// 调用方在此之后不可再读 [files] 里的 bytes。
  Future<List<ParsedFile>> parseFiles({
    required List<LoadedFile> files,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    void Function(int fileIndex, double fraction)? onProgress,
  }) async {
    final List<ParsedFile> results = [];
    for (int i = 0; i < files.length; i++) {
      final LoadedFile file = files[i];
      onProgress?.call(i, 0);
      final MxParseResult? result = await ParseIsolate.run(
        bytes: file.bytes,
        isMx: file.name.toLowerCase().endsWith(".mx"),
        cryptPairs: cryptPairs,
        onProgress: (double fraction) => onProgress?.call(i, fraction),
      );
      onProgress?.call(i, 1);
      // result 为 null 仅代表解析异常（格式损坏等）；空记录的结果原样保留，
      // 由上层结合 errorCount 区分「文件里没有日志」与「Key/IV 错误全部解密失败」
      results.add((name: file.name, result: result));
    }
    return results;
  }

  /// 解析成功后写入数据库，[onProgress] 回报写库真实进度（0.0-1.0）。
  /// [clearExisting] 为 true 时先清空旧数据（替换），否则追加合并
  /// （timestamp UNIQUE + INSERT OR IGNORE 天然去重）。
  Future<void> replaceWith({
    required List<MxParseResult> results,
    required String fileName,
    bool clearExisting = true,
    void Function(double fraction)? onProgress,
  }) =>
      _serial(() => _replaceWith(
            results: results,
            fileName: fileName,
            clearExisting: clearExisting,
            onProgress: onProgress,
          ));

  Future<void> _replaceWith({
    required List<MxParseResult> results,
    required String fileName,
    bool clearExisting = true,
    void Function(double fraction)? onProgress,
  }) async {
    final AnalyzerDatabase database = await _database;
    if (clearExisting) database.clear();
    final int total = results.fold(
        0, (int sum, MxParseResult result) => sum + result.records.length);
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
  Future<List<LogModel>> fetchLogs(LogFilterState filter, {int? limit, int? offset}) =>
      _serial(() async {
        final AnalyzerDatabase database = await _database;
        final List<Map<String, Object?>> rows =
            database.selectLogs(filter.toQuery(limit: limit, offset: offset));
        return rows.map(LogModel.fromJson).toList();
      });

  /// 当前过滤条件下的总条数（分页「共 N 条」与 hasMore 判断用）。
  Future<int> fetchLogsCount(LogFilterState filter) => _serial(() async {
        final AnalyzerDatabase database = await _database;
        return database.countLogs(filter.toQuery());
      });

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
