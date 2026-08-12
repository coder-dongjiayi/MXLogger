import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_screen.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';

import 'support/test_store.dart';

/// 头部统计可控完成的假数据层：只拦截 fetchHeaderInfo，
/// 空态/占位分支不会触达其余真实查询。
class _FakeHomeRepository extends EmptyRepository {
  _FakeHomeRepository(this._header);

  final Future<HeaderInfo> _header;

  @override
  Future<HeaderInfo> fetchHeaderInfo() => _header;
}

/// 回归：重新打开应用时 headerInfo 尚在异步加载，
/// 不能按「无数据」渲染，否则会闪现一下选择日志的空态卡片。
void main() {
  testWidgets("headerInfo 加载中显示空白占位，加载完成才显示空态卡片", (WidgetTester tester) async {
    final Completer<HeaderInfo> header = Completer<HeaderInfo>();
    final MXStore store =
        await createTestStore(repository: _FakeHomeRepository(header.future));

    await tester.pumpWidget(
      MXScope(
        store: store,
        child: MaterialApp(
          theme: MXTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("zh"),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pump();

    // 统计未返回：既不是空态卡片，也不是数据页（修复前这里会闪现空态）
    expect(find.text("拖入日志文件开始"), findsNothing);

    header.complete(const HeaderInfo(total: 0));
    await tester.pump();
    await tester.pump();

    // 确认无数据后才渲染空态卡片
    expect(find.text("拖入日志文件开始"), findsOneWidget);
  });
}
