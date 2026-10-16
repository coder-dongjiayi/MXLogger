import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_app.dart';
import 'package:web/web.dart' as web;

import 'package:mxlogger_chrome_prototype/browser_client.dart';
import 'package:mxlogger_chrome_prototype/browser_host.dart';
import 'package:mxlogger_chrome_prototype/browser_repository.dart';
import 'package:mxlogger_chrome_prototype/browser_fonts.dart';
import 'package:mxlogger_chrome_prototype/font_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final verify = Uri.base.queryParameters['verify'] == '1';
  runApp(_BrowserApp(verify: verify));
}

class _BrowserApp extends StatefulWidget {
  const _BrowserApp({required this.verify});
  final bool verify;
  @override
  State<_BrowserApp> createState() => _BrowserAppState();
}

class _BrowserAppState extends State<_BrowserApp> {
  final _client = BrowserClient();
  final _fonts = BrowserFonts();
  MXStore? _store;
  String? _error;
  String _startupStage = 'engine';
  int _startupLoaded = 0;
  int _startupTotal = 0;
  bool _fontsReady = false;
  SemanticsHandle? _semantics;
  StreamSubscription<LogFilterState>? _fontFilterSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.verify) _semantics = SemanticsBinding.instance.ensureSemantics();
    _client.onStartupProgress = (stage, loaded, total) {
      if (!mounted) return;
      setState(() {
        _startupStage = stage == 'ready' && !_fontsReady ? 'fonts' : stage;
        _startupLoaded = loaded;
        _startupTotal = total;
      });
    };
    _start();
  }

  Future<void> _start() async {
    try {
      late final Map<String, dynamic> initial;
      await Future.wait<void>([
        _client.open().then((value) => initial = value),
        _fonts.initialize().then((_) => _fontsReady = true),
      ]).timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw StateError('本地缓存读取超时，请关闭分析器后重新打开。'),
      );
      if (!mounted) return;
      _client.observeText = _fonts.observe;
      final browserHost = BrowserHost(observeText: _fonts.observe);
      final store = MXStore(
        host: browserHost.host,
        repository: BrowserRepository(
          _client,
          browserHost.files,
          fonts: _fonts,
        ),
      );
      _fontFilterSubscription = store.filter.stream.listen(
        (filter) => _fonts.observe(filter.keyword),
      );
      if ((initial['total'] as int) > 0) {
        store.screen.enter();
      } else {
        store.screen.resetToLanding();
      }
      setState(() => _store = store);
      if (widget.verify) _diagnostics(store, browserHost);
    } catch (error) {
      _client.dispose();
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : '分析器启动失败，请刷新页面后重试。',
        );
      }
    }
  }

  /// Only explicitly requested verification pages expose this interface.
  /// Imports use the same host/repository/store pipeline as real file selection.
  void _diagnostics(MXStore store, BrowserHost host) {
    web.window.setProperty(
      'mxPrototype'.toJS,
      {
        'fontProbe': ((JSString text) => _fonts.observe(text.toDart)).toJS,
        'call':
            ((JSString operation, JSString arguments) => _client
                    .call(
                      operation.toDart,
                      arguments:
                          (jsonDecode(arguments.toDart)
                              as Map<String, dynamic>),
                    )
                    .then((value) => jsonEncode(value).toJS)
                    .toJS)
                .toJS,
        'importSample': ((JSBoolean encrypted) => (() async {
          final name = encrypted.toDart
              ? 'sample_encrypted.mx'
              : 'sample_plain.mx';
          final response = await web.window.fetch('samples/$name'.toJS).toDart;
          final file = web.File([await response.blob().toDart].toJS, name);
          final paths = host.register([file]);
          store.crypt.saveEntries(
            encrypted.toDart ? [const CryptEntry(cryptKey: 'mxlogger123')] : [],
          );
          await store.importer.importFiles(paths);
          return jsonEncode(await _client.call('query')).toJS;
        })().toJS).toJS,
        'filter': ((JSString arguments) {
          final value = jsonDecode(arguments.toDart) as Map<String, dynamic>;
          store.filter.value = LogFilterState(
            keyword: value['keyword'] as String? ?? '',
            scope: MxSearchScope.values.byName(
              value['scope'] as String? ?? 'all',
            ),
            levels: (value['levels'] as List<dynamic>? ?? [])
                .cast<int>()
                .toSet(),
            tags: (value['tags'] as List<dynamic>? ?? []).cast<String>(),
            names: (value['names'] as List<dynamic>? ?? []).cast<String>(),
            fromUs: value['fromUs'] as int?,
            toUs: value['toUs'] as int?,
            ascending: value['ascending'] as bool? ?? false,
          );
        }).toJS,
        'state': (() => jsonEncode({
          'theme': store.themeMode.value.name,
          'locale': store.locale.value.languageCode,
          'cryptEntries': store.crypt.value.entries.length,
          'persistCrypt': store.crypt.persistEntries,
          'headerCollapsed': store.headerCollapsed.value,
          'fonts': {
            'loaded': _fonts.loaded,
            'cached': _fonts.cached,
            'missing': _fonts.hasMissing,
            'recommendedCjk': _fonts.recommendedCjk,
            'busy': _fonts.busy,
            'error': _fonts.error,
            'attempts': _fonts.downloadAttempts,
            'sourceIndex': _fonts.downloadSourceIndex,
          },
          'wizardFiles': store.wizardPaths.value.length,
          'canReparse': store.importer.canReparse,
          'importStatus': store.importer.value.status.name,
          'lastError': _client.lastError,
          'filter': {
            'keyword': store.filter.value.keyword,
            'scope': store.filter.value.scope.name,
          },
          'loaded': store.logList.value.valueOrNull?.logs.length,
          'matched': store.logList.value.valueOrNull?.total,
        }).toJS).toJS,
      }.jsify(),
    );
  }

  @override
  void dispose() {
    _fontFilterSubscription?.cancel();
    _store?.dispose();
    _semantics?.dispose();
    _client.dispose();
    _fonts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    if (store != null) {
      return MXScope(
        store: store,
        child: MXLoggerAnalyzerApp(
          fontFamily: 'NotoSansSC',
          homeBuilder: (context, child) =>
              BrowserFontShell(fonts: _fonts, child: child),
        ),
      );
    }
    final progress = _startupStage == 'cache' && _startupTotal > 0
        ? (_startupLoaded / _startupTotal).clamp(0.0, 1.0)
        : null;
    final message = switch (_startupStage) {
      'cache' => '正在读取上次的日志缓存…',
      'migrate' => '正在更新日志缓存，第一次打开可能需要几秒…',
      'index' => '正在恢复日志索引…',
      'save' => '正在保存日志缓存…',
      'fonts' => '正在加载本地字体…',
      'ready' => '正在打开日志列表…',
      _ => '正在启动本地解析器…',
    };
    return MaterialApp(
      title: 'MXLogger Analyzer',
      debugShowCheckedModeBanner: false,
      theme: MXTheme.dark().copyWith(
        textTheme: MXTheme.dark().textTheme.apply(fontFamily: 'NotoSansSC'),
      ),
      home: Scaffold(
        body: Center(
          child: _error == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Semantics(liveRegion: true, child: Text(message)),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).floor()}% · '
                        '${(_startupLoaded / 1048576).toStringAsFixed(1)} / '
                        '${(_startupTotal / 1048576).toStringAsFixed(1)} MiB',
                      ),
                    ],
                  ],
                )
              : Semantics(
                  liveRegion: true,
                  label: _error!,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(_error!),
                  ),
                ),
        ),
      ),
    );
  }
}
