import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/mx_scroll_behavior.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

class MXLoggerAnalyzerApp extends MXConsumerWidget {
  const MXLoggerAnalyzerApp({super.key, this.fontFamily, this.homeBuilder});

  /// Browser hosts bundle their own font so the complete UI works offline.
  final String? fontFamily;

  /// Optional host UI around the main page, inside the app's Navigator/theme.
  final Widget Function(BuildContext context, Widget child)? homeBuilder;

  ThemeData _font(ThemeData theme) => fontFamily == null
      ? theme
      : theme.copyWith(
          textTheme: theme.textTheme.apply(
            fontFamily: fontFamily,
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
          primaryTextTheme: theme.primaryTextTheme.apply(
            fontFamily: fontFamily,
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
          tooltipTheme: theme.tooltipTheme.copyWith(
            textStyle: theme.tooltipTheme.textStyle?.copyWith(
              fontFamily: fontFamily,
              fontFamilyFallback: MXTheme.monoFontFallback,
            ),
          ),
        );

  @override
  Widget build(BuildContext context, MXRef ref) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MXScrollBehavior(),
      theme: _font(MXTheme.light()),
      darkTheme: _font(MXTheme.dark()),
      themeMode: ref.watch(ref.store.themeMode),
      locale: ref.watch(ref.store.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: homeBuilder == null
          ? const MainScreen()
          : Builder(builder: (context) => homeBuilder!(context, const MainScreen())),
    );
  }
}
