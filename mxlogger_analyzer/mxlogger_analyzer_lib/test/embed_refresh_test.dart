import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

import 'support/test_store.dart';

/// 记录解析/入库调用的假数据层（不触达 isolate 与 sqlite）。
class _FakeHomeRepository extends EmptyRepository {
  /// 每次解析的文件路径
  final List<List<String>> parsedPaths = [];

  /// 每次入库是否清空旧数据
  final List<bool> writeClearExisting = [];
  bool hasData = false;

  @override
  Future<HeaderInfo> fetchHeaderInfo() async =>
      hasData ? const HeaderInfo(total: 3, fileName: "log.mx") : const HeaderInfo();

  @override
  Future<Map<int, int>> fetchLevelCounts() async => hasData ? {1: 3} : const {};

  @override
  Future<List<int>> fileSizes(List<String> paths) async =>
      List<int>.filled(paths.length, 1024);

  /// 假路径不落磁盘，直接给出空字节并把进度走满。
  /// 路径在这一层记录：parseFiles 收到的已经是读好的字节，看不到路径了
  @override
  Future<List<LoadedFile>> readFiles({
    required List<String> paths,
    required List<int> sizes,
    void Function(double fraction)? onProgress,
  }) async {
    parsedPaths.add(paths);
    onProgress?.call(1);
    return paths
        .map((String path) => (
              name: path.split(Platform.pathSeparator).last,
              bytes: Uint8List(0),
            ))
        .toList();
  }

  @override
  Future<List<ParsedFile>> parseFiles({
    required List<LoadedFile> files,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    void Function(int fileIndex, double fraction)? onProgress,
  }) async {
    return files
        .map((LoadedFile file) => (
              name: file.name,
              result: const MxParseResult(
                records: <LogRecord>[
                  LogRecord(
                    name: "n",
                    tag: "t",
                    msg: "m",
                    level: 1,
                    threadId: 1,
                    isMainThread: 1,
                    timestamp: 1700000000000000,
                  ),
                ],
              ),
            ))
        .toList();
  }

  @override
  Future<void> replaceWith({
    required List<MxParseResult> results,
    required String fileName,
    bool clearExisting = true,
    void Function(double fraction)? onProgress,
  }) async {
    writeClearExisting.add(clearExisting);
    hasData = true;
  }

  @override
  Future<void> clearAll() async => hasData = false;
}

/// 解析不出任何记录的假数据层：[errorCount] 为 0 模拟空日志文件（如刚初始化
/// 还没写过日志的 .mx），大于 0 模拟 Key/IV 错误导致的全部解密失败。
class _NoRecordsRepository extends _FakeHomeRepository {
  _NoRecordsRepository({required this.errorCount});

  final int errorCount;

  @override
  Future<List<ParsedFile>> parseFiles({
    required List<LoadedFile> files,
    List<MxCryptPair> cryptPairs = const <MxCryptPair>[],
    void Function(int fileIndex, double fraction)? onProgress,
  }) async {
    return files
        .map((LoadedFile file) => (
              name: file.name,
              result: MxParseResult(records: const [], errorCount: errorCount),
            ))
        .toList();
  }
}

/// 嵌入模式（悬浮球唤起）：打开不解析，用户点「刷新」才扫描本机日志目录，
/// 且每次刷新都是清空重解析。
void main() {
  final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  Future<void> pumpEmbedded(WidgetTester tester, MXStore store) async {
    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("空态只给「刷新日志」，不给拖入/选择文件", (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync("mx_embed_empty");
    addTearDown(() => dir.deleteSync(recursive: true));

    final MXStore store = await createTestStore(
      repository: _FakeHomeRepository(),
      initialPrefs: const {"mx_entered": true},
      diskcachePath: dir.path,
    );
    await pumpEmbedded(tester, store);

    expect(store.isEmbedded, isTrue);
    expect(find.text("刷新日志"), findsOneWidget);
    // 桌面端空态的拖入/选择文件文案不出现
    expect(find.text("拖入日志文件开始"), findsNothing);
    expect(find.text("选择日志文件"), findsNothing);

    // 目录里没有可解析文件：提示而不进入解析流程
    await tester.tap(find.text("刷新日志"));
    await tester.pumpAndSettle();
    expect(find.text("日志目录下没有可解析的文件"), findsOneWidget);
    expect(store.importer.value.isRunning, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("点刷新才扫描目录，且清空重解析", (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync("mx_embed_refresh");
    File("${dir.path}/2026-08-11_log.mx").writeAsBytesSync(<int>[0, 0, 0, 0]);
    File("${dir.path}/readme.md").writeAsStringSync("忽略非日志文件");
    addTearDown(() => dir.deleteSync(recursive: true));

    final _FakeHomeRepository repo = _FakeHomeRepository();
    final MXStore store = await createTestStore(
      repository: repo,
      initialPrefs: const {"mx_entered": true},
      diskcachePath: dir.path,
    );
    await pumpEmbedded(tester, store);

    // 打开分析器本身不触发任何解析
    expect(repo.parsedPaths, isEmpty);

    await tester.tap(find.text("刷新日志"));
    await tester.pumpAndSettle();

    // 只挑可解析的扩展名（readme.md 被忽略），且清空重解析
    expect(repo.parsedPaths.length, 1);
    expect(repo.parsedPaths.single, ["${dir.path}/2026-08-11_log.mx"]);
    expect(repo.writeClearExisting, [true]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("空日志文件刷新：提示没有可解析的日志，而不是 Key/IV 错误", (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync("mx_embed_norec");
    File("${dir.path}/log.mx").writeAsBytesSync(<int>[0, 0, 0, 0]);
    addTearDown(() => dir.deleteSync(recursive: true));

    final MXStore store = await createTestStore(
      repository: _NoRecordsRepository(errorCount: 0),
      initialPrefs: const {"mx_entered": true},
      diskcachePath: dir.path,
    );
    await pumpEmbedded(tester, store);

    await tester.tap(find.text("刷新日志"));
    await tester.pumpAndSettle();
    expect(find.text("没有可解析的日志文件"), findsOneWidget);
    expect(find.text("解析失败（格式或 Key/IV 有误）"), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("全部解密失败（errorCount > 0）仍提示 Key/IV 错误", (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync("mx_embed_badkey");
    File("${dir.path}/log.mx").writeAsBytesSync(<int>[0, 0, 0, 0]);
    addTearDown(() => dir.deleteSync(recursive: true));

    final MXStore store = await createTestStore(
      repository: _NoRecordsRepository(errorCount: 3),
      initialPrefs: const {"mx_entered": true},
      diskcachePath: dir.path,
    );
    await pumpEmbedded(tester, store);

    await tester.tap(find.text("刷新日志"));
    await tester.pumpAndSettle();
    expect(find.text("解析失败（格式或 Key/IV 有误）"), findsOneWidget);
    expect(find.text("没有可解析的日志文件"), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("有数据时 header 的刷新按钮（唯一入口）清库重解析", (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync("mx_embed_header");
    File("${dir.path}/log.mx").writeAsBytesSync(<int>[0, 0, 0, 0]);
    addTearDown(() => dir.deleteSync(recursive: true));

    final _FakeHomeRepository repo = _FakeHomeRepository()..hasData = true;
    final MXStore store = await createTestStore(
      repository: repo,
      initialPrefs: const {"mx_entered": true},
      diskcachePath: dir.path,
    );
    await pumpEmbedded(tester, store);

    // header 的「更换文件」被替换为刷新，且只此一处（不再有左下角悬浮刷新）
    expect(find.byIcon(Icons.drive_folder_upload_outlined), findsNothing);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(tester.getCenter(find.byIcon(Icons.refresh)).dy, lessThan(844 * 0.3));

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(repo.parsedPaths.single, ["${dir.path}/log.mx"]);
    expect(repo.writeClearExisting, [true]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets("桌面壳（非嵌入）仍是拖入/选择文件空态与更换文件按钮", (WidgetTester tester) async {
    final MXStore store = await createTestStore(
      repository: _FakeHomeRepository(),
      initialPrefs: const {"mx_entered": true},
    );
    await pumpEmbedded(tester, store);

    expect(store.isEmbedded, isFalse);
    expect(find.text("刷新日志"), findsNothing);
    expect(find.text("拖入日志文件开始"), findsOneWidget);
  });
}
