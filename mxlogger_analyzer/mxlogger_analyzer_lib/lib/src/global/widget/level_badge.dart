import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/level/mx_level.dart';

/// 日志等级徽标（对齐设计稿 levelTagStyle）：
/// FATAL 为白字实底，其余等级色文字 + 10% 底 + 55% 描边。
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color color = tokens.levelColor(level);
    final bool fatal = level == 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: fatal ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: fatal ? color : color.withValues(alpha: 0.55)),
      ),
      child: Text(
        mxLevelName(level),
        style: TextStyle(
          color: fatal ? Colors.white : color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          fontFamilyFallback: MXTheme.monoFontFallback,
          height: 1.5,
        ),
      ),
    );
  }
}
