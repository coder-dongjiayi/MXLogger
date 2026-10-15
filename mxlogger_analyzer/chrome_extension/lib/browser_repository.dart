import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_app.dart';
import 'package:web/web.dart' as web;

import 'package:mxlogger_chrome_prototype/browser_client.dart';
import 'package:mxlogger_chrome_prototype/browser_fonts.dart';

/// UI receives only pages and aggregate results; parsed records remain in the
/// worker that owns the SQLite connection and import transaction.
class BrowserRepository extends HomeRepository {
  BrowserRepository(this.client, this.files, {this.fonts})
    : super(() => throw UnsupportedError('SQLite is owned by the worker.'));

  final BrowserClient client;
  final Map<String, web.File> files;
  final BrowserFonts? fonts;

  Map<String, Object?> _filter(LogFilterState filter) => {
    'keyword': filter.keyword,
    'scope': filter.scope.name,
    'levels': filter.levels.toList(),
    'tags': filter.tags,
    'names': filter.names,
    'fromUs': filter.fromUs,
    'toUs': filter.toUs,
    'ascending': filter.ascending,
  };

  List<LogModel> _rows(Object? value) {
    final rows = (value as List<dynamic>)
        .map((row) => LogModel.fromJson((row as Map).cast<String, Object?>()))
        .toList();
    for (final row in rows.take(100)) {
      fonts?.observe(row.msg);
      fonts?.observe(row.name);
      fonts?.observe(row.tag);
      fonts?.observe(row.fileHeader);
    }
    return rows;
  }

  @override
  Future<void> importFiles({
    required List<String> paths,
    List<MxCryptPair> cryptPairs = const [],
    bool clearExisting = true,
    void Function(ImportProgress)? onProgress,
  }) async {
    final selected = paths.map((path) => files[path]).toList();
    if (selected.any((file) => file == null)) {
      throw const ImportFailure(ImportError.readFailed);
    }
    await client.call(
      'importFiles',
      files: [for (final file in selected) file!],
      arguments: {
        'clearExisting': clearExisting,
        'cryptPairs': cryptPairs
            .map((pair) => {'key': pair.key, 'iv': pair.iv})
            .toList(),
      },
      onProgress: onProgress,
    );
    // Retain only the current sources for reparse and the next wizard selection.
    // web.File handles do not retain decoded byte buffers on the UI thread.
    files.removeWhere((path, _) => !paths.contains(path));
  }

  @override
  Future<void> clearAll() async {
    await client.call('clear');
    files.clear();
    fonts?.resetNeeded();
  }

  @override
  Future<List<LogModel>> fetchLogs(
    LogFilterState filter, {
    int? limit,
    int? offset,
  }) async => _rows(
    (await client.call(
      'logs',
      arguments: {..._filter(filter), 'limit': limit, 'offset': offset},
    ))['rows'],
  );

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async =>
      (await client.call('count', arguments: _filter(filter)))['matched']
          as int;

  @override
  Future<LogContext> fetchContext(LogModel anchor, {int limit = 20}) async {
    final result = await client.call(
      'context',
      arguments: {'timestamp': anchor.timestamp, 'limit': limit},
    );
    return (
      older: _rows(result['older']),
      newer: _rows(result['newer']),
      olderCount: result['olderCount'] as int,
      total: result['total'] as int,
    );
  }

  @override
  Future<List<LogModel>> fetchOlderThan(
    int timestampUs, {
    int limit = 20,
  }) async => _rows(
    (await client.call(
      'older',
      arguments: {'timestamp': timestampUs, 'limit': limit},
    ))['rows'],
  );

  @override
  Future<List<LogModel>> fetchNewerThan(
    int timestampUs, {
    int limit = 20,
  }) async => _rows(
    (await client.call(
      'newer',
      arguments: {'timestamp': timestampUs, 'limit': limit},
    ))['rows'],
  );

  @override
  Future<Map<int, int>> fetchLevelCounts() async {
    final result = await client.call('levels');
    return (result['levels'] as Map).map(
      (key, value) => MapEntry(int.parse(key as String), value as int),
    );
  }

  @override
  Future<List<String>> fetchTagOptions() => _options('tags');

  @override
  Future<List<String>> fetchNameOptions() => _options('names');

  Future<List<String>> _options(String key) async {
    final values = ((await client.call('options'))[key] as List<dynamic>)
        .cast<String>();
    for (final value in values) {
      fonts?.observe(value);
    }
    return values;
  }

  @override
  Future<int> fetchCount() async =>
      (await client.call('count'))['total'] as int;

  @override
  Future<HeaderInfo> fetchHeaderInfo() async {
    final result = await client.call('header');
    fonts?.observe(result['fileName'] as String?);
    fonts?.observe(result['fileHeader'] as String?);
    return HeaderInfo(
      total: result['total'] as int,
      minUs: result['minUs'] as int?,
      maxUs: result['maxUs'] as int?,
      fileName: result['fileName'] as String? ?? '',
      header: HeaderInfo.parseHeader(result['fileHeader'] as String?),
    );
  }
}
