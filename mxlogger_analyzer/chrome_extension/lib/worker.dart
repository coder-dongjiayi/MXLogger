import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_core.dart';
import 'package:sqlite3/wasm.dart';
import 'package:web/web.dart' as web;

/// Compiled separately from Flutter: decoding and SQL never block rendering.
void main() {
  final self = globalContext as web.DedicatedWorkerGlobalScope;
  final database = _BrowserDatabase();
  Future<void> queue = Future<void>.value();
  void send(Map<String, Object?> message) =>
      self.postMessage(jsonEncode(message).toJS);
  self.onmessage = (web.MessageEvent event) {
    final envelope = event.data as JSObject;
    final request =
        jsonDecode(envelope.getProperty<JSString>('payload'.toJS).toDart)
            as Map<String, dynamic>;
    final id = request['id'] as int;
    final bytes = envelope.getProperty<JSUint8Array?>('bytes'.toJS)?.toDart;
    final files = envelope
        .getProperty<JSArray<web.File>?>('files'.toJS)
        ?.toDart;
    queue = queue.then((_) async {
      try {
        final result = await database.handle(request, bytes, files, (progress) {
          send({
            'id': id,
            'progress': {
              'step': progress.step.name,
              'percent': progress.percent,
              'fileLabel': progress.fileLabel,
            },
          });
        });
        send({'id': id, 'result': result});
      } catch (error) {
        send({
          'id': id,
          'error': '无法完成操作，请重新打开分析器后重试。',
          if (error is ImportFailure) 'importError': error.error.name,
        });
      }
    });
  }.toJS;
}

class _BrowserDatabase {
  WasmSqlite3? _sqlite;
  AnalyzerDatabase? _database;
  IndexedDbFileSystem? _fileSystem;

  Future<void> _open() async {
    if (_database != null) return;
    final sqlite = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    _sqlite = sqlite;
    final fileSystem = await IndexedDbFileSystem.open(
      // Preserve caches imported by phase-one installations.
      dbName: 'mxlogger-analyzer-prototype',
    );
    sqlite.registerVirtualFileSystem(fileSystem, makeDefault: true);
    final database = AnalyzerDatabase.fromConnection(
      sqlite.open('/mxlogger_analyzer.db'),
    )..open();
    _fileSystem = fileSystem;
    _database = database;
  }

  Future<Map<String, Object?>> handle(
    Map<String, dynamic> request,
    Uint8List? bytes,
    List<web.File>? files,
    void Function(ImportProgress) progress,
  ) async {
    await _open();
    final database = _database!;
    switch (request['op']) {
      case 'importFiles':
      case 'import':
        return _import(request, bytes, files, progress);
      case 'clear':
        // Clearing a cache can delete the entire closed file. DELETE on every
        // row would journal a large previous database just to discard it.
        database.dispose();
        _database = null;
        _fileSystem!.xDelete('/mxlogger_analyzer.db', 0);
        await _fileSystem!.flush();
        _database = AnalyzerDatabase.fromConnection(
          _sqlite!.open('/mxlogger_analyzer.db'),
        )..open();
        await _fileSystem!.flush();
        return _query(request);
      case 'init':
      case 'query':
        return _query(request);
      case 'logs':
        return {'rows': database.selectLogs(_filter(request))};
      case 'count':
        return {
          'total': database.count(),
          'matched': database.countLogs(_filter(request)),
        };
      case 'levels':
        return {'levels': _levels()};
      case 'options':
        return {
          'tags': database.distinctTags(),
          'names': database.distinctNames(),
        };
      case 'header':
        final bounds = database.timeBounds();
        return {
          'total': database.count(),
          'minUs': bounds?.minUs,
          'maxUs': bounds?.maxUs,
          'fileName': database.getMeta('fileName'),
          'fileHeader': database.firstFileHeader(),
        };
      case 'context':
        final timestamp = request['timestamp'] as int;
        return {
          'older': _nearby(timestamp, false, request['limit'] as int? ?? 20),
          'newer': _nearby(timestamp, true, request['limit'] as int? ?? 20),
          'olderCount': database.countLogs(LogQuery(toUs: timestamp - 1)),
          'total': database.count(),
        };
      case 'older':
      case 'newer':
        return {
          'rows': _nearby(
            request['timestamp'] as int,
            request['op'] == 'newer',
            request['limit'] as int? ?? 20,
          ),
        };
      default:
        throw ArgumentError('Unknown operation: ${request['op']}');
    }
  }

  Future<Map<String, Object?>> _import(
    Map<String, dynamic> request,
    Uint8List? bytes,
    List<web.File>? files,
    void Function(ImportProgress) progress,
  ) async {
    final stopwatch = Stopwatch()..start();
    final names =
        files?.map((file) => file.name).toList() ??
        [request['name'] as String? ?? 'log.mx'];
    final sizes =
        files?.map((file) => file.size).toList() ?? [bytes?.length ?? 0];
    final totalBytes = sizes.fold(0, (int sum, size) => sum + size);
    final label =
        '${names.length > 1 ? "${names.first} +${names.length - 1}" : names.first}  (${mxFmtBytes(totalBytes)})';
    int lastPercent = -1;
    ImportStep? lastStep;
    void report(ImportStep step, double value) {
      final percent = value.clamp(0, 100).round();
      if (step != lastStep || percent != lastPercent) {
        lastPercent = percent;
        lastStep = step;
        progress(
          ImportProgress(step: step, percent: percent, fileLabel: label),
        );
      }
    }

    final loaded = <Uint8List?>[];
    report(ImportStep.reading, 0);
    try {
      if (files != null) {
        int done = 0;
        for (final file in files) {
          final buffer = Uint8List(file.size);
          for (int offset = 0; offset < file.size;) {
            final end = (offset + 4 * 1024 * 1024).clamp(0, file.size);
            final chunk = (await file.slice(offset, end).arrayBuffer().toDart)
                .toDart
                .asUint8List();
            if (chunk.length != end - offset) {
              throw StateError('Incomplete file read');
            }
            buffer.setRange(offset, end, chunk);
            done += chunk.length;
            offset = end;
            if (totalBytes > 0) {
              report(ImportStep.reading, 8 * done / totalBytes);
            }
          }
          loaded.add(buffer);
        }
      } else if (bytes != null) {
        loaded.add(bytes);
      } else {
        throw StateError('Missing file');
      }
    } catch (_) {
      throw const ImportFailure(ImportError.readFailed);
    }
    final pairs = (request['cryptPairs'] as List<dynamic>? ?? [])
        .map(
          (pair) => MxCryptPair(
            key: pair['key'] as String,
            iv: pair['iv'] as String? ?? '',
          ),
        )
        .toList();
    final parsed = <MxParseResult>[];
    final usableNames = <String>[];
    bool suspect = false;
    int before = 0;
    report(ImportStep.decrypting, 8);
    for (int i = 0; i < loaded.length; i++) {
      try {
        final result = MxBinaryParser.parse(
          loaded[i]!,
          cryptPairs: pairs,
          onProgress: (processed, total) {
            if (totalBytes > 0 && total > 0) {
              report(
                ImportStep.decrypting,
                8 + 70 * (before + sizes[i] * processed / total) / totalBytes,
              );
            }
          },
        );
        suspect |= result.errorCount > 0;
        if (result.records.isNotEmpty) {
          parsed.add(result);
          usableNames.add(names[i]);
        }
      } catch (_) {
        suspect = true;
      } finally {
        loaded[i] = null;
      }
      before += sizes[i];
    }
    if (parsed.isEmpty) {
      throw ImportFailure(
        suspect ? ImportError.parseFailed : ImportError.noRecords,
      );
    }
    report(ImportStep.indexing, 78);
    final InsertSummary inserted;
    try {
      inserted = _database!.importResults(
        parsed,
        fileName: usableNames.length > 1
            ? '${usableNames.first} +${usableNames.length - 1}'
            : usableNames.first,
        clearExisting: request['clearExisting'] as bool? ?? true,
        onProgress: (processed, total) {
          if (total > 0) {
            report(ImportStep.indexing, 78 + 21 * processed / total);
          }
        },
      );
      // The VFS mirrors writes asynchronously. Success requires persistence.
      await _fileSystem!.flush();
    } catch (_) {
      throw const ImportFailure(ImportError.writeFailed);
    }
    report(ImportStep.done, 100);
    return {
      'imported': inserted.inserted,
      'duplicated': inserted.duplicated,
      'parseErrors': parsed.fold<int>(
        0,
        (int sum, result) => sum + result.errorCount,
      ),
      'elapsedMs': stopwatch.elapsedMilliseconds,
    };
  }

  LogQuery _filter(Map<String, dynamic> request, {int? defaultLimit}) =>
      LogQuery(
        keyword: request['keyword'] as String?,
        scope: MxSearchScope.values.byName(
          request['scope'] as String? ?? 'all',
        ),
        levels: (request['levels'] as List<dynamic>?)?.cast<int>(),
        tags: (request['tags'] as List<dynamic>?)?.cast<String>(),
        names: (request['names'] as List<dynamic>?)?.cast<String>(),
        fromUs: request['fromUs'] as int?,
        toUs: request['toUs'] as int?,
        ascending: request['ascending'] as bool? ?? true,
        limit: request['limit'] as int? ?? defaultLimit,
        offset: request['offset'] as int?,
      );

  List<Map<String, Object?>> _nearby(int timestamp, bool newer, int limit) =>
      _database!.selectLogs(
        LogQuery(
          fromUs: newer ? timestamp + 1 : null,
          toUs: newer ? null : timestamp - 1,
          ascending: newer,
          limit: limit,
        ),
      );

  Map<String, int> _levels() =>
      _database!.levelCounts().map((key, value) => MapEntry('$key', value));

  Map<String, Object?> _query(Map<String, dynamic> request) {
    final database = _database!;
    final query = _filter(request, defaultLimit: 100);
    return {
      'total': database.count(),
      'matched': database.countLogs(query),
      'fileName': database.getMeta('fileName'),
      'fileHeader': database.firstFileHeader(),
      'levels': _levels(),
      'rows': database.selectLogs(query),
    };
  }
}
