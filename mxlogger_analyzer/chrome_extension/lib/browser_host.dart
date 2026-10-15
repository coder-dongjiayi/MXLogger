import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_app.dart';
import 'package:web/web.dart' as web;

/// Decryption parameters stay in memory unless the user opts into local storage.
class BrowserPrefs extends MXMemoryPrefs implements MXCryptPersistencePrefs {
  static const _cryptPreference = 'mx_crypt_persist';
  static const _cryptKeys = {'mx_crypt_entries', 'mx_crypt_key', 'mx_crypt_iv'};
  static const _persisted = {
    'mxlogger-theme',
    'mxlogger-locale',
    'mx_entered',
    _cryptPreference,
  };

  BrowserPrefs() : super(_load());

  static Map<String, Object> _load() {
    final storage = web.window.localStorage;
    final values = <String, Object>{
      for (final key in _persisted)
        if (storage.getItem(key) case final String value)
          key: value == 'true'
              ? true
              : value == 'false'
              ? false
              : value,
    };
    for (final key in _cryptKeys) {
      if (values[_cryptPreference] == true) {
        if (storage.getItem(key) case final String value) values[key] = value;
      } else {
        storage.removeItem(key);
      }
    }
    return values;
  }

  @override
  bool get persistCrypt => getBool(_cryptPreference) ?? false;

  @override
  void setPersistCrypt(bool enabled) {
    final storage = web.window.localStorage;
    for (final key in _cryptKeys) {
      if (enabled) {
        if (getString(key) case final String value) storage.setItem(key, value);
      } else {
        storage.removeItem(key);
      }
    }
    setBool(_cryptPreference, enabled);
  }

  @override
  void setString(String key, String value) {
    super.setString(key, value);
    if (_persisted.contains(key) ||
        (persistCrypt && _cryptKeys.contains(key))) {
      web.window.localStorage.setItem(key, value);
    }
  }

  @override
  void setBool(String key, bool value) {
    super.setBool(key, value);
    if (_persisted.contains(key)) {
      web.window.localStorage.setItem(key, '$value');
    }
  }
}

class BrowserHost {
  BrowserHost({this.observeText});
  final void Function(String?)? observeText;
  final files = <String, web.File>{};
  final _handles = <String, String>{};
  int _sequence = 0;

  late final host = MXHost(
    prefs: BrowserPrefs(),
    pickLogFiles: pickFiles,
    share: _share,
    openExternalLink: _openExternalLink,
    dropTargetBuilder:
        ({required child, required onDrop, required onDragOver}) =>
            _BrowserDropTarget(
              onFiles: (selected) => onDrop(register(selected)),
              onDragOver: onDragOver,
              child: child,
            ),
  );

  List<String> register(List<web.File> selected) {
    return selected
        .where((file) => file.name.toLowerCase().endsWith('.mx'))
        .map((file) {
          observeText?.call(file.name);
          final identity = '${file.name}:${file.size}:${file.lastModified}';
          final handle = _handles.putIfAbsent(
            identity,
            () => 'browser/${++_sequence}/${file.name}',
          );
          files[handle] = file;
          return handle;
        })
        .toList();
  }

  Future<List<String>> pickFiles() async {
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.mx'
      ..multiple = true
      ..style.display = 'none';
    web.document.body!.append(input);
    final selected = Completer<List<String>>();
    input.onchange = (web.Event _) {
      final list = input.files;
      final result = <web.File>[];
      if (list != null) {
        for (int i = 0; i < list.length; i++) {
          result.add(list.item(i)!);
        }
      }
      input.remove();
      if (!selected.isCompleted) selected.complete(register(result));
    }.toJS;
    input.oncancel = (web.Event _) {
      input.remove();
      if (!selected.isCompleted) selected.complete([]);
    }.toJS;
    input.click();
    return selected.future;
  }

  Future<bool> _share(MXShareRequest request) async {
    if (request.fileName == null) return false; // Shared UI copies plain text.
    final blob = web.Blob(
      [request.text.toJS].toJS,
      web.BlobPropertyBag(type: 'text/plain;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = request.fileName!;
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
    return true;
  }

  Future<bool> _openExternalLink(Uri uri) async {
    // 在点击回调内同步打开，保留浏览器的用户手势。
    final anchor = web.HTMLAnchorElement()
      ..href = uri.toString()
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    web.document.body!.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  }
}

/// Document-level listeners also cover Flutter's canvas. They exist only while
/// the active analyzer page is mounted and ignore ordinary text drags.
class _BrowserDropTarget extends StatefulWidget {
  const _BrowserDropTarget({
    required this.child,
    required this.onFiles,
    required this.onDragOver,
  });
  final Widget child;
  final ValueChanged<List<web.File>> onFiles;
  final ValueChanged<bool> onDragOver;
  @override
  State<_BrowserDropTarget> createState() => _BrowserDropTargetState();
}

class _BrowserDropTargetState extends State<_BrowserDropTarget> {
  final _listeners = <String, JSFunction>{};
  int _depth = 0;

  @override
  void initState() {
    super.initState();
    for (final type in ['dragenter', 'dragover', 'dragleave', 'drop']) {
      final handler = ((web.Event event) {
        final drag = event as web.DragEvent;
        final transfer = drag.dataTransfer;
        if (transfer == null ||
            !transfer.types.toDart.any((type) => type.toDart == 'Files')) {
          return;
        }
        drag.preventDefault();
        if (type == 'dragenter') {
          _depth++;
          if (_depth == 1) widget.onDragOver(true);
        } else if (type == 'dragover') {
          transfer.dropEffect = 'copy';
        } else if (type == 'dragleave') {
          _depth = (_depth - 1).clamp(0, 1 << 30);
          if (_depth == 0) widget.onDragOver(false);
        } else {
          _depth = 0;
          widget.onDragOver(false);
          final files = transfer.files;
          widget.onFiles([
            for (int i = 0; i < files.length; i++) files.item(i)!,
          ]);
        }
      }).toJS;
      _listeners[type] = handler;
      web.document.addEventListener(type, handler);
    }
  }

  @override
  void dispose() {
    for (final entry in _listeners.entries) {
      web.document.removeEventListener(entry.key, entry.value);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
