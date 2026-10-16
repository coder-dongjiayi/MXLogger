import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:sqlite3/wasm.dart';

@JS('mxReadLogCache')
external JSPromise<JSArray<JSObject>> _readLogCache(JSFunction progress);

@JS('mxWriteLogCache')
external JSPromise<JSAny?> _writeLogCache(JSUint8Array bytes);

/// SQLite still runs in memory, as with IndexedDbFileSystem. Persist only a
/// committed database, atomically, instead of restoring thousands of 4 KiB
/// blobs through one asynchronous cursor callback per page on every launch.
class BrowserCache {
  static const databasePath = '/mxlogger_analyzer.db';
  final fileSystem = InMemoryFileSystem();
  bool needsSave = true;

  Future<void> open({
    required void Function(String stage, int loaded, int total) onProgress,
  }) async {
    final files = await _readLogCache(
      ((JSString stage, JSNumber loaded, JSNumber total) {
        onProgress(stage.toDart, loaded.toDartInt, total.toDartInt);
      }).toJS,
    ).toDart;
    needsSave = files.toDart.isEmpty;
    for (final entry in files.toDart) {
      needsSave |=
          entry.getProperty<JSBoolean?>('legacy'.toJS)?.toDart ?? false;
      final path = entry.getProperty<JSString>('name'.toJS).toDart;
      final bytes = entry.getProperty<JSUint8Array>('bytes'.toJS).toDart;
      final file = fileSystem
          .xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_CREATE)
          .file;
      try {
        file.xWrite(bytes, 0);
      } finally {
        file.xClose();
      }
    }
  }

  /// Called after COMMIT, including after recovering a legacy rollback journal.
  /// IndexedDB replaces the snapshot in one transaction; failed saves retain
  /// the last committed snapshot. The worker serializes all cache operations.
  Future<void> flush() async {
    final data = fileSystem.fileData[databasePath];
    final bytes = data == null
        ? Uint8List(0)
        : data.buffer.asUint8List(0, data.length);
    await _writeLogCache(bytes.toJS).toDart;
  }
}
