import 'dart:io';
import 'dart:ui' as ui;

import 'package:example/demo_l10n.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Exercises the desktop UI against real native logging. The temporary root keeps
/// the user's demo logs untouched. Images come only from this app's widget tree.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;

  testWidgets(
    'macOS demo: settings, writes, isolates, navigation and filtering',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('mxlogger_macos_demo_');
      final captureKey = GlobalKey();
      DemoL10n.language.value = DemoL10n.en;
      binding.reportData = {'screenshots': <Map<String, dynamic>>[]};

      Future<void> waitFor(Finder finder) async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
        while (DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          if (finder.evaluate().isNotEmpty) return;
        }
        fail('Timed out waiting for $finder');
      }

      Future<void> capture(String name) async {
        debugPrint('DEMO_CAPTURE: $name');
        await tester.pumpAndSettle();
        final boundary = captureKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List().toList();
        });
        (binding.reportData!['screenshots'] as List).add({
          'screenshotName': name,
          'bytes': bytes!,
        });
      }

      Future<void> scrollTo(String text) async {
        await tester.scrollUntilVisible(
          find.text(text),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }

      try {
        runApp(
          RepaintBoundary(
            key: captureKey,
            child: MXDemoApp(directory: root.path),
          ),
        );
        await tester.pumpAndSettle();
        await capture('macos-01-landing');
        await tester.tap(find.text(tr('landing.enter')));
        await waitFor(find.text(tr('home.section.write')));
        await tester.pumpAndSettle();
        await capture('macos-02-home');

        for (final level in ['Debug', 'Info', 'Warn', 'Error', 'Fatal']) {
          final title = tr('home.write.level.title', [level]);
          await scrollTo(title);
          await tester.tap(find.text(title));
          await tester.pump(const Duration(milliseconds: 200));
        }
        for (final key in ['network', 'custom', 'key']) {
          final title = tr('home.write.$key.title');
          await scrollTo(title);
          await tester.tap(find.text(title));
          await tester.pump(const Duration(milliseconds: 200));
        }
        await tester.pump(const Duration(seconds: 2));

        // Desktop settings use a dialog; mobile retains the bottom sheet.
        final levelTitle = tr('home.config.level.title');
        for (final option in ['Warn (2)', 'Debug (0)']) {
          await scrollTo(levelTitle);
          await tester.tap(find.text(levelTitle));
          await tester.pumpAndSettle();
          expect(find.byType(SimpleDialog), findsOneWidget);
          await tester.tap(find.text(option));
          await tester.pumpAndSettle();
        }
        await scrollTo(tr('home.config.age.title'));
        expect(find.text(tr('home.config.background.title')), findsNothing);
        expect(
          find.textContaining(tr('home.config.macos.cleanup')),
          findsOneWidget,
        );
        await capture('macos-03-configuration');

        await scrollTo(tr('home.perf.thread.title'));
        await tester.tap(find.text(tr('home.perf.thread.title')));
        await waitFor(find.text(tr('verify.pass.title')));
        await capture('macos-04-concurrent-verify');
        await tester.tap(find.text(tr('common.ok')));
        await tester.pumpAndSettle();

        await scrollTo(tr('home.info.finder.title'));
        // Verify the macOS-only channel without opening a Finder window in a test.
        await expectLater(
          const MethodChannel(
            'com.mxlogger.demo/desktop',
          ).invokeMethod<void>('openDirectory', '${root.path}/does-not-exist'),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              'directory_missing',
            ),
          ),
        );
        await capture('macos-05-instance-info');

        await tester.tap(find.text('中文'));
        await tester.pumpAndSettle();
        expect(find.text('在 Finder 中打开'), findsOneWidget);
        await capture('macos-06-chinese');
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();

        await scrollTo(tr('home.file.browse.title'));
        await tester.tap(find.text(tr('home.file.browse.title')));
        await waitFor(find.byIcon(Icons.description));
        await capture('macos-07-file-list');
        await tester.tap(find.byIcon(Icons.description).first);
        await waitFor(find.text('INFO'));
        await capture('macos-08-viewer');
        await tester.tap(find.text('Info'));
        await tester.enterText(find.byType(TextField), 'long message');
        await tester.pumpAndSettle();
        expect(find.textContaining('payload-'), findsWidgets);
        await capture('macos-09-filter');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        root.deleteSync(recursive: true);
        DemoL10n.language.value = DemoL10n.en;
      }
    },
    skip: !Platform.isMacOS,
  );
}
