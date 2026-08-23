import 'package:flutter/widgets.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';

export 'package:mxlogger_analyzer_lib/src/app/l10n/gen/app_localizations.dart';

/// 统一文案入口：业务代码通过 `context.l10n.xxx` 取多语言文案。
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
