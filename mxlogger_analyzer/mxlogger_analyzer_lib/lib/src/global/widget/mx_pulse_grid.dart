import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 8 宫格脉冲加载动画（4 列 x 2 行，对齐设计稿导入 loading）。
/// 导入进度页与日志列表分页加载共用。
class MXPulseGrid extends StatefulWidget {
  const MXPulseGrid({super.key});

  @override
  State<MXPulseGrid> createState() => _MXPulseGridState();
}

class _MXPulseGridState extends State<MXPulseGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // 4 列 x 2 行（对齐设计稿 grid-template-columns:repeat(4,14px)）
        return SizedBox(
          width: 4 * 14 + 3 * 5,
          child: Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (int i = 0; i < 8; i++) _square(tokens, i),
            ],
          ),
        );
      },
    );
  }

  /// 对齐设计稿 pageMap 关键帧：25% 处闪强调色，逐格延迟 0.12s
  Widget _square(MXTokens tokens, int index) {
    final double t = (_controller.value - index * 0.12 / 1.4) % 1.0;
    final double phase = t < 0 ? t + 1 : t;
    // 0→25% 渐入强调色，25%→60% 渐出，其余保持底色
    double intensity = 0;
    if (phase < 0.25) {
      intensity = phase / 0.25;
    } else if (phase < 0.6) {
      intensity = 1 - (phase - 0.25) / 0.35;
    }
    final Color bg = Color.lerp(
          tokens.panel2,
          Color.lerp(tokens.panel2, tokens.accent, 0.65),
          intensity,
        ) ??
        tokens.panel2;
    final Color border = Color.lerp(tokens.border, tokens.accent, intensity) ?? tokens.border;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3.5),
        border: Border.all(color: border),
      ),
    );
  }
}
