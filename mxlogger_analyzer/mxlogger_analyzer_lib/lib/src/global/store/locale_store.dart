import 'dart:ui';

import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';

const String _localeKey = "mxlogger-locale";

/// 界面语言：未手动选择过则跟随系统（仅支持中/英，其余回落英文）。
class LocaleStore extends MXState<Locale> {
  LocaleStore(MXPrefs prefs)
      : _prefs = prefs,
        super(_initial(prefs));

  final MXPrefs _prefs;

  static Locale _initial(MXPrefs prefs) {
    final String? saved = prefs.getString(_localeKey);
    if (saved != null) return Locale(saved);
    // 取 PlatformDispatcher 而非 WidgetsBinding：store 可在无 binding 的
    // 纯 Dart 测试里构造
    final String system = PlatformDispatcher.instance.locale.languageCode;
    return Locale(system == "zh" ? "zh" : "en");
  }

  /// 中英互切并持久化
  void toggle() {
    final Locale next =
        value.languageCode == "zh" ? const Locale("en") : const Locale("zh");
    value = next;
    _prefs.setString(_localeKey, next.languageCode);
  }
}
