import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';

class MXLoggerAnalyzerApp extends MXConsumerWidget {
  const MXLoggerAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context, MXRef ref) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: MXTheme.light(),
      darkTheme: MXTheme.dark(),
      themeMode: ref.watch(ref.store.themeMode),
      locale: ref.watch(ref.store.locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainScreen(),
    );
  }
}
