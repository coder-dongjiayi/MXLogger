import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/app.dart';
import 'package:mxlogger_analyzer_lib/src/app/mx_scroll_behavior.dart';
import 'package:mxlogger_analyzer_lib/src/embed/mx_analyzer.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

import 'support/test_store.dart';

class _LogRepository extends EmptyRepository {
  static final List<LogModel> _logs = List<LogModel>.generate(
    40,
    (int index) => LogModel(
      id: index + 1,
      name: 'network',
      msg: 'Log entry $index',
      level: 1,
      timestamp: 1700000000000000 + index * 1000000,
    ),
  );

  @override
  Future<HeaderInfo> fetchHeaderInfo() async =>
      HeaderInfo(total: _logs.length, fileName: 'log.mx');

  @override
  Future<Map<int, int>> fetchLevelCounts() async => {1: _logs.length};

  @override
  Future<List<LogModel>> fetchLogs(
    LogFilterState filter, {
    int? limit,
    int? offset,
  }) async => _logs.skip(offset ?? 0).take(limit ?? _logs.length).toList();

  @override
  Future<int> fetchLogsCount(LogFilterState filter) async => _logs.length;
}

Future<BuildContext> _scrollContext(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  const Key key = ValueKey('scroll-context');
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      scrollBehavior: const MXScrollBehavior(),
      home: const SizedBox(key: key),
    ),
  );
  return tester.element(find.byKey(key));
}

void main() {
  for (final bool embedded in [false, true]) {
    testWidgets(
      'macOS trackpad scroll survives an update older than the start event '
      '(${embedded ? 'embedded' : 'standalone'})',
      (WidgetTester tester) async {
        tester.view
          ..physicalSize = const Size(1280, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = await createTestStore(
          repository: _LogRepository(),
          initialPrefs: const {'mx_entered': true},
          diskcachePath: embedded ? '/tmp/mx_not_exists' : null,
        );
        await tester.pumpWidget(
          embedded
              ? MaterialApp(home: MXAnalyzerEmbedApp(store: store))
              : MXScope(store: store, child: const MXLoggerAnalyzerApp()),
        );
        await tester.pumpAndSettle();

        final Finder list = find.byType(ListView);
        expect(list, findsOneWidget);
        final ScrollPosition position = tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position;
        final Offset location = tester.getCenter(list);
        final TestGesture gesture = await tester.createGesture(
          kind: PointerDeviceKind.trackpad,
        );
        // Match the reported 94,891 microsecond timestamp reversal.
        await gesture.panZoomStart(
          location,
          timeStamp: const Duration(microseconds: 1000000),
        );
        await gesture.panZoomUpdate(
          location,
          pan: const Offset(35, -231),
          timeStamp: const Duration(microseconds: 905109),
        );
        expect(tester.takeException(), isNull);
        for (int index = 1; index <= 3; index++) {
          await gesture.panZoomUpdate(
            location,
            pan: Offset(35, -231 - index * 40),
            timeStamp: Duration(microseconds: 905109 + index * 16000),
          );
        }
        expect(position.pixels, greaterThan(0));
        final double beforeRelease = position.pixels;
        await gesture.panZoomEnd(
          timeStamp: const Duration(microseconds: 969109),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(position.pixels, greaterThan(beforeRelease));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      },
      variant: const TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }

  testWidgets('ordered samples retain native macOS fling estimates', (
    WidgetTester tester,
  ) async {
    final BuildContext context = await _scrollContext(
      tester,
      TargetPlatform.macOS,
    );
    final VelocityTracker tracker = ScrollConfiguration.of(
      context,
    ).velocityTrackerBuilder(context)(const PointerPanZoomStartEvent());
    final VelocityTracker native = MacOSScrollViewFlingVelocityTracker(
      PointerDeviceKind.trackpad,
    );
    for (final (int milliseconds, Offset position) in [
      (0, Offset.zero),
      (16, const Offset(0, -40)),
      (32, const Offset(0, -80)),
      (32, const Offset(0, -80)),
      (48, const Offset(0, -120)),
    ]) {
      tracker.addPosition(Duration(milliseconds: milliseconds), position);
      native.addPosition(Duration(milliseconds: milliseconds), position);
    }
    final VelocityEstimate actual = tracker.getVelocityEstimate()!;
    final VelocityEstimate expected = native.getVelocityEstimate()!;
    expect(actual.pixelsPerSecond, expected.pixelsPerSecond);
    expect(actual.duration, expected.duration);
    expect(actual.offset, expected.offset);
    expect(tracker.getVelocity(), native.getVelocity());
  });

  testWidgets('repeated timestamp reversals discard obsolete fling history', (
    WidgetTester tester,
  ) async {
    final BuildContext context = await _scrollContext(
      tester,
      TargetPlatform.macOS,
    );
    final VelocityTracker tracker = ScrollConfiguration.of(
      context,
    ).velocityTrackerBuilder(context)(const PointerPanZoomStartEvent());
    tracker.addPosition(const Duration(seconds: 1), Offset.zero);
    tracker.addPosition(
      const Duration(milliseconds: 900),
      const Offset(0, -100),
    );
    tracker.addPosition(
      const Duration(milliseconds: 916),
      const Offset(0, -140),
    );
    // A second reversal during the same gesture also starts a fresh history.
    for (int index = 0; index <= 3; index++) {
      tracker.addPosition(
        Duration(milliseconds: 800 + index * 16),
        Offset(0, -200.0 - index * 40),
      );
    }
    final VelocityEstimate estimate = tracker.getVelocityEstimate()!;
    expect(estimate.duration, const Duration(milliseconds: 48));
    expect(estimate.offset, const Offset(0, -120));
    expect(estimate.pixelsPerSecond.dx, 0);
    expect(estimate.pixelsPerSecond.dy, closeTo(-2500, 0.001));
    expect(tracker.getVelocity().pixelsPerSecond, estimate.pixelsPerSecond);
  });

  testWidgets('other platforms and macOS touch keep their default trackers', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final BuildContext context = await _scrollContext(tester, platform);
      for (final PointerDeviceKind kind in [
        PointerDeviceKind.trackpad,
        PointerDeviceKind.touch,
      ]) {
        if (platform == TargetPlatform.macOS &&
            kind == PointerDeviceKind.trackpad) {
          continue;
        }
        final PointerEvent event = kind == PointerDeviceKind.trackpad
            ? const PointerPanZoomStartEvent()
            : const PointerDownEvent();
        final VelocityTracker actual = ScrollConfiguration.of(
          context,
        ).velocityTrackerBuilder(context)(event);
        final VelocityTracker expected = const MaterialScrollBehavior()
            .velocityTrackerBuilder(context)(event);
        expect(actual.runtimeType, expected.runtimeType);
        expect(actual.kind, kind);
      }
    }
  });
}
