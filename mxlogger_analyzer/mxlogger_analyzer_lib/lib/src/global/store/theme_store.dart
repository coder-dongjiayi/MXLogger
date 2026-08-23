import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';

const String _themeKey = "mxlogger-theme";

/// 主题模式：对齐设计稿默认深色，用户选择持久化。
class ThemeModeStore extends MXState<ThemeMode> {
  ThemeModeStore(MXPrefs prefs)
      : _prefs = prefs,
        super(prefs.getString(_themeKey) == "light" ? ThemeMode.light : ThemeMode.dark);

  final MXPrefs _prefs;

  void toggle() {
    final ThemeMode next = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    value = next;
    _prefs.setString(_themeKey, next == ThemeMode.light ? "light" : "dark");
  }
}
