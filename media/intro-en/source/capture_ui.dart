// Capture the project's real English widgets with illustrative log records.
// Run from mxlogger_analyzer/mxlogger_analyzer_lib with flutter test <this file>.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_detail_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

final int baseTime = DateTime(2026, 10, 12, 9, 41).microsecondsSinceEpoch;
final List<LogModel> records = [
  LogModel(id: 6, name: 'checkout', tag: 'payment,timeout', level: 3,
    timestamp: baseTime + 6000000,
    msg: jsonEncode({'event': 'payment_timeout', 'requestId': 'req_0842',
      'statusCode': 504, 'durationMs': 5000, 'retry': {'attempt': 2, 'limit': 3}})),
  LogModel(id: 5, name: 'network', tag: 'POST,retry', level: 2,
    timestamp: baseTime + 5000000, msg: 'Request timed out. Retrying in 500 ms.'),
  LogModel(id: 4, name: 'network', tag: 'POST,200', level: 1,
    timestamp: baseTime + 4000000,
    msg: jsonEncode({'method': 'POST', 'path': '/v1/cart', 'statusCode': 200,
      'durationMs': 42, 'items': 3})),
  LogModel(id: 3, name: 'auth', tag: 'login,session', level: 0,
    timestamp: baseTime + 3000000, msg: 'Session validated. Cache hit.'),
  LogModel(id: 2, name: 'checkout', tag: 'cart,payment', level: 1,
    timestamp: baseTime + 2000000, msg: 'Checkout started. 3 items in cart.'),
  LogModel(id: 1, name: 'app', tag: 'startup', level: 1,
    timestamp: baseTime + 1000000, msg: 'Application ready. Logger initialized.'),
];

class DemoRepository extends HomeRepository {
  DemoRepository() : super(() => throw StateError('Capture uses sample records.'));
  List<LogModel> filtered(LogFilterState f) => records.where((r) =>
    (f.levels.isEmpty || f.levels.contains(r.level)) &&
    (f.keyword.isEmpty || '${r.msg} ${r.name} ${r.tag}'.toLowerCase().contains(f.keyword.toLowerCase()))
  ).toList();
  @override Future<HeaderInfo> fetchHeaderInfo() async => HeaderInfo(
    total: records.length, minUs: baseTime + 1000000,
    maxUs: baseTime + 6000000, fileName: '2026-10-12_app.mx');
  @override Future<Map<int, int>> fetchLevelCounts() async => {0: 1, 1: 3, 2: 1, 3: 1};
  @override Future<List<LogModel>> fetchLogs(LogFilterState f, {int? limit, int? offset}) async => filtered(f);
  @override Future<int> fetchLogsCount(LogFilterState f) async => filtered(f).length;
  @override Future<List<String>> fetchTagOptions() async => ['payment', 'network', 'POST', 'retry'];
  @override Future<List<String>> fetchNameOptions() async => ['checkout', 'network', 'auth'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture English analyzer for introduction video', (tester) async {
    for (final family in ['VideoSans', 'Roboto', 'Ahem']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(
        File('/System/Library/Fonts/Supplemental/Arial.ttf').readAsBytesSync())));
      await loader.load();
    }
    final material = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await material.load();
    final symbols = FontLoader('VideoSymbols')..addFont(Future.value(ByteData.sublistView(
      File('/System/Library/Fonts/Apple Symbols.ttf').readAsBytesSync())));
    await symbols.load();
    for (final family in ['VideoMono', 'Menlo', 'monospace', 'SF Mono']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.sublistView(
        File('/System/Library/Fonts/Menlo.ttc').readAsBytesSync())));
      await loader.load();
    }
    final output = Directory('${Directory.current.path}/../../media/intro-en/working/ui')..createSync(recursive: true);
    final key = GlobalKey();
    final store = MXStore(host: MXHost(prefs: MXMemoryPrefs({'mx_entered': true, 'mxlogger-locale': 'en'}),
      pickLogFiles: () async => []), repository: DemoRepository());
    addTearDown(store.dispose);
    Widget app(Widget home) => MXScope(store: store, child: RepaintBoundary(key: key,
      child: MaterialApp(debugShowCheckedModeBanner: false,
        theme: MXTheme.dark().copyWith(textTheme: MXTheme.dark().textTheme.apply(fontFamily: 'VideoSans')),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales, home: home)));
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      // Flutter's headless test engine substitutes Ahem for unqualified fonts.
      // Restore readable fonts on rendered text without changing app sources.
      InlineSpan readable(InlineSpan span, String family) {
        if (span is! TextSpan) return span;
        final style = span.style;
        final selected = style?.fontFamily == 'MaterialIcons' ? 'MaterialIcons'
          : style?.fontFamilyFallback?.contains('Menlo') == true ? 'VideoMono' : family;
        return TextSpan(text: span.text, style: (style ?? const TextStyle()).copyWith(
          fontFamily: selected, fontFamilyFallback: const ['VideoSymbols', 'VideoSans', 'VideoMono']),
          children: span.children?.map((s) => readable(s, selected)).toList(),
          recognizer: span.recognizer, semanticsLabel: span.semanticsLabel);
      }
      for (final paragraph in tester.allRenderObjects.whereType<RenderParagraph>()) {
        paragraph.text = readable(paragraph.text, 'VideoSans');
      }
      for (final editable in tester.allRenderObjects.whereType<RenderEditable>()) {
        if (editable.text != null) editable.text = readable(editable.text!, 'VideoMono');
      }
      await tester.pump();
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2.5));
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      output.uri.resolve('$name.png').toFilePath();
      File('${output.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      image!.dispose();
      expect(tester.takeException(), isNull);
    }
    tester.view..physicalSize = const Size(440, 840)..devicePixelRatio = 1;
    await tester.pumpWidget(app(const MainScreen()));
    await capture('mobile');
    await tester.tap(find.text('ERROR').first);
    await capture('mobile-filter');
    tester.view.physicalSize = const Size(1200, 820);
    await tester.pumpWidget(app(Builder(builder: (context) => Scaffold(body: Center(
      child: TextButton(onPressed: () => showLogDetailDialog(context, log: records.first), child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await capture('detail');
    tester.view.physicalSize = const Size(440, 840);
    await capture('detail-mobile');
    tester.view.physicalSize = const Size(1200, 820);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(const MainScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand all'));
    await capture('desktop');
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
