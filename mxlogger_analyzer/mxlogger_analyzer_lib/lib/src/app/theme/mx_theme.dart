import 'package:flutter/material.dart';

/// 设计稿 MXLogger.dc.html 的双主题 design tokens，全工程唯一颜色来源。
/// 业务代码通过 `MXTokens.of(context)` 取色，禁止散落 hex。
class MXTokens extends ThemeExtension<MXTokens> {
  const MXTokens({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.border,
    required this.text,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.onAccent,
    required this.headerGrad,
    required this.mask,
    required this.markText,
    required this.hl,
    required this.lvDebug,
    required this.lvInfo,
    required this.lvWarning,
    required this.lvError,
    required this.lvFatal,
    required this.jsonKey,
    required this.jsonStr,
    required this.jsonNum,
    required this.jsonBool,
    required this.nameText,
    required this.tagText,
    required this.cardShadow,
  });

  final Color bg;
  final Color panel;
  final Color panel2;
  final Color border;
  final Color text;
  final Color muted;
  final Color faint;
  final Color accent;
  final Color onAccent;
  final Color headerGrad;
  final Color mask;
  final Color markText;
  final Color hl;
  final Color lvDebug;
  final Color lvInfo;
  final Color lvWarning;
  final Color lvError;
  final Color lvFatal;
  final Color jsonKey;
  final Color jsonStr;
  final Color jsonNum;
  final Color jsonBool;

  /// @name 徽标色（紫，与 info 等级蓝区分）
  final Color nameText;

  /// #tag 徽标色（青绿，比 muted 灰更醒目）
  final Color tagText;
  final List<BoxShadow> cardShadow;

  /// dark: --bg:#050506 --panel:#1E1E24 --panel-2:#30303A --border:#44444F ...
  static const MXTokens dark = MXTokens(
    bg: Color(0xFF050506),
    panel: Color(0xFF1E1E24),
    panel2: Color(0xFF30303A),
    border: Color(0xFF44444F),
    text: Color(0xFFE7E7EB),
    muted: Color(0xFF9B9BA6),
    faint: Color(0xFF64646E),
    accent: Color(0xFF4C9BE8),
    onAccent: Color(0xFF08101E),
    headerGrad: Color(0xFF17171B),
    mask: Color(0xB8000000),
    markText: Color(0xFFFFE6B0),
    hl: Color(0xFFE8B44C),
    lvDebug: Color(0xFF6B7A94),
    lvInfo: Color(0xFF4C9BE8),
    lvWarning: Color(0xFFE8B44C),
    lvError: Color(0xFFE85C5C),
    lvFatal: Color(0xFFC21E63),
    jsonKey: Color(0xFF7FB4F0),
    jsonStr: Color(0xFF8FD49A),
    jsonNum: Color(0xFFE8B44C),
    jsonBool: Color(0xFFF0427C),
    nameText: Color(0xFFB48CF0),
    tagText: Color(0xFF4FC0B0),
    cardShadow: [BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 3)],
  );

  /// light: --bg:#F2F4F9 --panel:#FFFFFF --panel-2:#EAEEF5 --border:#D8DEE9 ...
  static const MXTokens light = MXTokens(
    bg: Color(0xFFF2F4F9),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFEAEEF5),
    border: Color(0xFFD8DEE9),
    text: Color(0xFF1C2638),
    muted: Color(0xFF5C6A84),
    faint: Color(0xFF7E8AA2),
    accent: Color(0xFF1E6FC7),
    onAccent: Color(0xFFFFFFFF),
    headerGrad: Color(0xFFEAEEF6),
    mask: Color(0x591E283C),
    markText: Color(0xFF6B4A00),
    hl: Color(0xFFE8B44C),
    lvDebug: Color(0xFF64748B),
    lvInfo: Color(0xFF1E6FC7),
    lvWarning: Color(0xFF9A6C08),
    lvError: Color(0xFFD14343),
    lvFatal: Color(0xFFA81858),
    jsonKey: Color(0xFF1D64C0),
    jsonStr: Color(0xFF177A3E),
    jsonNum: Color(0xFFA05E00),
    jsonBool: Color(0xFFC22566),
    nameText: Color(0xFF6E3BD1),
    tagText: Color(0xFF0E8578),
    cardShadow: [BoxShadow(color: Color(0x14182A3A), offset: Offset(0, 1), blurRadius: 2)],
  );

  static MXTokens of(BuildContext context) {
    return Theme.of(context).extension<MXTokens>() ?? dark;
  }

  /// 等级色：0 debug / 1 info / 2 warning / 3 error / 4 fatal
  Color levelColor(int level) {
    switch (level) {
      case 0:
        return lvDebug;
      case 1:
        return lvInfo;
      case 2:
        return lvWarning;
      case 3:
        return lvError;
      case 4:
        return lvFatal;
      default:
        return lvDebug;
    }
  }

  @override
  MXTokens copyWith() => this;

  @override
  MXTokens lerp(MXTokens? other, double t) {
    if (other == null) return this;
    Color lc(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return MXTokens(
      bg: lc(bg, other.bg),
      panel: lc(panel, other.panel),
      panel2: lc(panel2, other.panel2),
      border: lc(border, other.border),
      text: lc(text, other.text),
      muted: lc(muted, other.muted),
      faint: lc(faint, other.faint),
      accent: lc(accent, other.accent),
      onAccent: lc(onAccent, other.onAccent),
      headerGrad: lc(headerGrad, other.headerGrad),
      mask: lc(mask, other.mask),
      markText: lc(markText, other.markText),
      hl: lc(hl, other.hl),
      lvDebug: lc(lvDebug, other.lvDebug),
      lvInfo: lc(lvInfo, other.lvInfo),
      lvWarning: lc(lvWarning, other.lvWarning),
      lvError: lc(lvError, other.lvError),
      lvFatal: lc(lvFatal, other.lvFatal),
      jsonKey: lc(jsonKey, other.jsonKey),
      jsonStr: lc(jsonStr, other.jsonStr),
      jsonNum: lc(jsonNum, other.jsonNum),
      jsonBool: lc(jsonBool, other.jsonBool),
      nameText: lc(nameText, other.nameText),
      tagText: lc(tagText, other.tagText),
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

class MXTheme {
  MXTheme._();

  /// 日志正文/时间戳使用等宽字体，跨平台按可用性回退（对齐设计稿 ui-monospace 链）
  static const List<String> monoFontFallback = [
    "SF Mono",
    "Menlo",
    "Monaco",
    "Cascadia Code",
    "JetBrains Mono",
    "Consolas",
    "monospace",
  ];

  static ThemeData dark() => _build(MXTokens.dark, Brightness.dark);

  static ThemeData light() => _build(MXTokens.light, Brightness.light);

  static ThemeData _build(MXTokens tokens, Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      surface: tokens.panel,
      onSurface: tokens.text,
      onSurfaceVariant: tokens.muted,
      surfaceContainerHighest: tokens.panel2,
      outline: tokens.border,
      error: tokens.lvError,
      onError: Colors.white,
    );

    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.bg,
      splashFactory: NoSplash.splashFactory,
      fontFamilyFallback: const ["PingFang SC", "Microsoft YaHei"],
      dividerTheme: DividerThemeData(color: tokens.border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: tokens.panel2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: tokens.border),
        ),
        textStyle: TextStyle(color: tokens.text, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.accent,
        linearTrackColor: tokens.panel2,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: tokens.text, displayColor: tokens.text),
      extensions: <ThemeExtension<dynamic>>[tokens],
    );
  }
}
