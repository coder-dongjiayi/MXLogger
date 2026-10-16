import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_core.dart';
import 'package:web/web.dart' as web;

@JS('mxAcquireWorkspace')
external JSPromise<JSBoolean> _acquireWorkspace();

class BrowserClient {
  web.Worker? _worker;
  int _sequence = 0;
  String? lastError;
  void Function(String?)? observeText;
  void Function(String stage, int loaded, int total)? onStartupProgress;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _progress = <int, void Function(ImportProgress)>{};

  Future<Map<String, dynamic>> open() async {
    if (!(await _acquireWorkspace().toDart).toDart) {
      throw StateError('分析器已在另一个标签页打开，请先关闭那个页面。');
    }
    final worker = web.Worker('worker.js'.toJS);
    _worker = worker;
    worker.onmessage = (web.MessageEvent event) {
      final message =
          jsonDecode((event.data as JSString).toDart) as Map<String, dynamic>;
      final id = message['id'] as int;
      if (message.containsKey('startup')) {
        final startup = message['startup'] as Map<String, dynamic>;
        onStartupProgress?.call(
          startup['stage'] as String,
          startup['loaded'] as int,
          startup['total'] as int,
        );
        return;
      }
      if (message.containsKey('progress')) {
        final progress = message['progress'] as Map<String, dynamic>;
        observeText?.call(progress['fileLabel'] as String?);
        _progress[id]?.call(
          ImportProgress(
            step: ImportStep.values.byName(progress['step'] as String),
            percent: progress['percent'] as int,
            fileLabel: progress['fileLabel'] as String,
          ),
        );
        return;
      }
      final pending = _pending.remove(id);
      _progress.remove(id);
      if (pending == null) return;
      if (message.containsKey('error')) {
        final code = message['importError'] as String?;
        lastError = code ?? message['error'] as String;
        pending.completeError(
          code == null
              ? StateError(message['error'] as String)
              : ImportFailure(ImportError.values.byName(code)),
        );
      } else {
        pending.complete(message['result'] as Map<String, dynamic>);
      }
    }.toJS;
    worker.onerror = (web.Event event) {
      _failPending(StateError('后台解析器启动失败，请重新打开分析器。'));
    }.toJS;
    return call('init');
  }

  Future<Map<String, dynamic>> call(
    String operation, {
    Map<String, Object?> arguments = const {},
    Uint8List? bytes,
    List<web.File>? files,
    void Function(ImportProgress)? onProgress,
  }) {
    final worker = _worker;
    if (worker == null) throw StateError('解析器尚未启动。');
    final id = ++_sequence;
    final pending = Completer<Map<String, dynamic>>();
    _pending[id] = pending;
    if (onProgress != null) _progress[id] = onProgress;
    // File/Blob structured clones share immutable backing storage. Reading and
    // decoding large files happens in the worker, without UI-side byte copies.
    if (operation == 'import' || operation == 'importFiles') lastError = null;
    try {
      final envelope = JSObject();
      envelope.setProperty(
        'payload'.toJS,
        jsonEncode({'id': id, 'op': operation, ...arguments}).toJS,
      );
      if (bytes != null) envelope.setProperty('bytes'.toJS, bytes.toJS);
      if (files != null) {
        envelope.setProperty('files'.toJS, files.toList().toJS);
      }
      worker.postMessage(envelope);
    } catch (error) {
      lastError = '$error';
      _pending.remove(id);
      _progress.remove(id);
      pending.completeError(error);
    }
    return pending.future;
  }

  Future<Map<String, dynamic>> importSample(bool encrypted) async {
    final name = encrypted ? 'sample_encrypted.mx' : 'sample_plain.mx';
    final response = await web.window.fetch('samples/$name'.toJS).toDart;
    if (!response.ok) throw StateError('无法读取示例日志。');
    final bytes = (await response.arrayBuffer().toDart).toDart.asUint8List();
    return call(
      'import',
      bytes: bytes,
      arguments: {
        'name': name,
        'cryptPairs': encrypted
            ? [
                {'key': 'mxlogger123', 'iv': ''},
              ]
            : [],
      },
    );
  }

  void _failPending(Object error) {
    for (final pending in _pending.values) {
      pending.completeError(error);
    }
    _pending.clear();
    _progress.clear();
  }

  void dispose() {
    _worker?.terminate();
    _worker = null;
    _failPending(StateError('分析器已关闭。'));
  }
}
