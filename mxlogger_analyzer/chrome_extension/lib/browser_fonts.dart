import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

@JS('mxFontStore')
external JSPromise<JSAny?> _fontStore(JSString action, [JSAny? record]);
@JS('mxFontDigest')
external JSPromise<JSString> _digest(JSUint8Array bytes);
@JS('mxInspectFont')
external JSPromise<JSString> _inspect(JSUint8Array bytes);
@JS('mxDownloadFont')
external JSPromise<JSObject> _download(
  JSArray<JSString> urls,
  JSString expectedHash,
  JSFunction progress,
);
@JS('mxCancelFontDownload')
external void _cancelDownload();

class InstalledFont {
  InstalledFont(
    this.id,
    this.name,
    this.bytes,
    this.coverage, {
    this.cached = true,
  });
  final String id;
  final String name;
  final int bytes;
  final Set<int> coverage;
  bool cached;
}

/// Only font bytes and glyph coverage enter the font store/download bridge.
class BrowserFonts extends ChangeNotifier {
  final installed = <InstalledFont>[];
  final _bundled = <int>{};
  final _needed = <int>{};
  Map<String, dynamic> _pack = {};
  bool busy = false;
  String stage = '';
  String? error;
  int received = 0;
  int downloadSourceIndex = 0;
  List<Map<String, dynamic>> downloadAttempts = [];
  int revision = 0;
  bool _disposed = false;

  int get downloadBytes => _pack['downloadBytes'] as int? ?? 0;
  List<Map<String, dynamic>> get downloadSources =>
      (_pack['sources'] as List<dynamic>).cast<Map<String, dynamic>>();
  String sourceName(int index) => downloadSources[index]['name'] as String;
  int get missingCount => _needed.where((cp) => !covers(cp)).length;
  bool get hasMissing => missingCount > 0;
  bool get cached => installed.any((font) => font.cached);
  bool get loaded => installed.isNotEmpty;
  bool get recommendedCjk =>
      web.window.navigator.language.startsWith('zh') ||
      web.window.navigator.language.startsWith('ja') ||
      _needed.any(
        (cp) =>
            !covers(cp) &&
            (cp >= 0x3000 && cp <= 0x9fff || cp >= 0x20000 && cp <= 0x323af),
      );
  bool covers(int cp) =>
      _bundled.contains(cp) ||
      installed.any((font) => font.coverage.contains(cp));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Set<int> _coverage(String json) {
    final result = <int>{};
    for (final range in jsonDecode(json) as List<dynamic>) {
      final first = range[0] as int, last = range[1] as int;
      if (first < 0 || last > 0x10ffff || first > last) {
        throw const FormatException();
      }
      for (int cp = first; cp <= last; cp++) {
        result.add(cp);
      }
    }
    return result;
  }

  Future<void> initialize() async {
    final response = await web.window.fetch('font-manifest.json'.toJS).toDart;
    if (!response.ok) throw StateError('Font manifest missing');
    final manifest =
        jsonDecode((await response.text().toDart).toDart)
            as Map<String, dynamic>;
    _pack = manifest['pack'] as Map<String, dynamic>;
    _bundled.addAll(_coverage(jsonEncode(manifest['bundledRanges'])));
    try {
      final records =
          (await _fontStore('list'.toJS).toDart) as JSArray<JSObject>;
      for (final record in records.toDart) {
        try {
          final bytes = record.getProperty<JSUint8Array>('bytes'.toJS).toDart;
          final hash = (await _digest(bytes.toJS).toDart).toDart;
          if (hash != record.getProperty<JSString>('id'.toJS).toDart) {
            throw const FormatException();
          }
          final ranges = record.getProperty<JSString>('ranges'.toJS).toDart;
          await _load(bytes);
          installed.add(
            InstalledFont(
              hash,
              record.getProperty<JSString>('name'.toJS).toDart,
              bytes.length,
              _coverage(ranges),
            ),
          );
        } catch (_) {
          error = 'cacheRestore';
        }
      }
    } catch (_) {
      error = 'cacheRestore';
    }
  }

  void observe(String? text) {
    if (text == null || text.isEmpty) return;
    final previouslyMissing = hasMissing;
    _addNeeded(text);
    // JSON trees display decoded strings, including escaped Unicode.
    if (text.contains('\\u') &&
        (text.trimLeft().startsWith('{') || text.trimLeft().startsWith('['))) {
      try {
        _observeJson(jsonDecode(text));
      } catch (_) {
        /* Plain text is kept as-is. */
      }
    }
    if (previouslyMissing != hasMissing) _notify();
  }

  void _observeJson(Object? value, [int depth = 0]) {
    if (depth > 64) return;
    if (value is String) {
      _addNeeded(value);
    } else if (value is Map) {
      for (final entry in value.entries) {
        _addNeeded('${entry.key}');
        _observeJson(entry.value, depth + 1);
      }
    } else if (value is List) {
      for (final child in value) {
        _observeJson(child, depth + 1);
      }
    }
  }

  void _addNeeded(String text) {
    for (final cp in text.runes) {
      if (cp < 32 ||
          cp == 127 ||
          cp == 0xad ||
          cp == 0x61c ||
          cp >= 0x200b && cp <= 0x200f ||
          cp >= 0x202a && cp <= 0x202e ||
          cp >= 0x2060 && cp <= 0x206f ||
          cp == 0xfeff ||
          cp >= 0xfe00 && cp <= 0xfe0f ||
          cp >= 0xe0000 && cp <= 0xe007f ||
          cp >= 0xe0100 && cp <= 0xe01ef) {
        continue;
      }
      _needed.add(cp);
    }
  }

  void resetNeeded() {
    _needed.clear();
    _notify();
  }

  Future<void> installOnline() async {
    if (busy) return;
    busy = true;
    error = null;
    stage = 'download';
    received = 0;
    downloadSourceIndex = 0;
    downloadAttempts = [];
    _notify();
    try {
      final result = await _download(
        downloadSources
            .map((source) => (source['url'] as String).toJS)
            .toList()
            .toJS,
        (_pack['sha256'] as String).toJS,
        ((JSNumber count, JSNumber index) {
          received = count.toDartInt;
          downloadSourceIndex = index.toDartInt;
          _notify();
        }).toJS,
      ).toDart;
      downloadAttempts =
          (jsonDecode(result.getProperty<JSString>('attempts'.toJS).toDart)
                  as List<dynamic>)
              .cast<Map<String, dynamic>>();
      final failure = result.getProperty<JSString?>('error'.toJS)?.toDart;
      if (failure != null) {
        error = failure == 'cancelled' ? null : 'download';
        return;
      }
      final bytes = result.getProperty<JSUint8Array>('bytes'.toJS).toDart;
      stage = 'validate';
      _notify();
      final hash = (await _digest(bytes.toJS).toDart).toDart;
      if (hash != _pack['sha256']) throw const FormatException();
      await _install(bytes, 'Noto Sans SC', hash: hash);
    } catch (_) {
      error = stage == 'download' ? 'download' : 'invalid';
    } finally {
      busy = false;
      stage = '';
      _notify();
    }
  }

  void cancelDownload() => _cancelDownload();

  Future<void> importFile() async {
    if (busy) return;
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.woff2,.ttf,.otf';
    input.style.display = 'none';
    web.document.body!.append(input);
    final selected = Completer<web.File?>();
    input.onchange = ((web.Event _) {
      final file = input.files?.item(0);
      input.remove();
      if (!selected.isCompleted) selected.complete(file);
    }).toJS;
    input.oncancel = ((web.Event _) {
      input.remove();
      if (!selected.isCompleted) selected.complete(null);
    }).toJS;
    input.click();
    final file = await selected.future;
    if (file == null || _disposed || busy) return;
    busy = true;
    stage = 'validate';
    error = null;
    _notify();
    try {
      if (file.size > 32 * 1024 * 1024 || file.size < 12) {
        throw const FormatException();
      }
      await _install(
        (await file.arrayBuffer().toDart).toDart.asUint8List(),
        file.name,
      );
    } catch (_) {
      error = 'invalid';
    } finally {
      busy = false;
      stage = '';
      _notify();
    }
  }

  Future<void> _load(Uint8List bytes) {
    final loader = FontLoader('MXLogFont')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    return loader.load();
  }

  Future<void> _install(Uint8List bytes, String name, {String? hash}) async {
    if (bytes.length < 12 ||
        bytes.length > 32 * 1024 * 1024 ||
        !{
          0x00010000,
          0x4f54544f,
          0x774f4632,
        }.contains(ByteData.sublistView(bytes).getUint32(0))) {
      throw const FormatException();
    }
    final id = hash ?? (await _digest(bytes.toJS).toDart).toDart;
    final existing = installed.where((font) => font.id == id).firstOrNull;
    final ranges = existing == null
        ? (await _inspect(bytes.toJS).toDart).toDart
        : jsonEncode(_ranges(existing.coverage));
    if (existing == null) {
      await _load(bytes);
      installed.add(
        InstalledFont(id, name, bytes.length, _coverage(ranges), cached: false),
      );
      revision++;
    }
    final record = JSObject()
      ..setProperty('id'.toJS, id.toJS)
      ..setProperty('name'.toJS, name.toJS)
      ..setProperty('bytes'.toJS, bytes.toJS)
      ..setProperty('ranges'.toJS, ranges.toJS);
    stage = 'save';
    _notify();
    try {
      await _fontStore('put'.toJS, record).toDart;
      installed.firstWhere((font) => font.id == id).cached = true;
    } catch (_) {
      error = 'cacheSave';
    }
  }

  List<List<int>> _ranges(Set<int> points) {
    final result = <List<int>>[];
    for (final cp in points.toList()..sort()) {
      if (result.isNotEmpty && result.last[1] + 1 == cp) {
        result.last[1] = cp;
      } else {
        result.add([cp, cp]);
      }
    }
    return result;
  }

  Future<void> removeCached(String id) async {
    if (busy) return;
    try {
      await _fontStore('delete'.toJS, id.toJS).toDart;
      installed.firstWhere((font) => font.id == id).cached = false;
      error = null;
    } catch (_) {
      error = 'cacheSave';
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelDownload();
    super.dispose();
  }
}
