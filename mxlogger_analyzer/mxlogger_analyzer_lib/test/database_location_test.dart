import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/data_header.dart';

import 'support/test_store.dart';

class _Repository extends EmptyRepository {
  final uri = Uri.file('/tmp/MXLogger logs/mxlogger_analyzer.db');
  bool prepared = false;

  @override
  Future<Uri> prepareDatabaseFile() async {
    prepared = true;
    return uri;
  }
}

Future<void> _pumpHeader(WidgetTester tester, MXStore store) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MXScope(
      store: store,
      child: MaterialApp(
        theme: MXTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: DataHeader()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('文件夹按钮在分享左边，点击先准备数据库再交给宿主', (tester) async {
    final repository = _Repository();
    Uri? opened;
    final store = await createTestStore(
      repository: repository,
      host: MXHost(
        openDatabaseLocation: (uri) async {
          expect(repository.prepared, isTrue);
          opened = uri;
          return true;
        },
      ),
    );
    await _pumpHeader(tester, store);
    final folder = find.byTooltip('打开数据库目录');
    final share = find.byTooltip('分享日志（当前筛选结果）');
    expect(tester.getCenter(folder).dx, lessThan(tester.getCenter(share).dx));
    expect(tester.getCenter(folder).dy, tester.getCenter(share).dy);
    await tester.tap(folder);
    await tester.pumpAndSettle();
    expect(opened, repository.uri);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未提供文件夹能力时隐藏入口', (tester) async {
    await _pumpHeader(tester, await createTestStore());
    expect(find.byTooltip('打开数据库目录'), findsNothing);
  });

  for (final throws in [false, true]) {
    testWidgets('宿主${throws ? "抛错" : "返回失败"}时显示提示', (tester) async {
      final store = await createTestStore(
        repository: _Repository(),
        host: MXHost(
          openDatabaseLocation: (_) async {
            if (throws) throw StateError('unavailable');
            return false;
          },
        ),
      );
      await _pumpHeader(tester, store);
      await tester.tap(find.byTooltip('打开数据库目录'));
      await tester.pumpAndSettle();
      expect(find.text('无法打开数据库目录，请重试'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }
}
