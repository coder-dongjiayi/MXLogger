import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_pulse_grid.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';

/// 导入加载态（对齐设计稿）：8 宫格脉冲动画 + 文件名 + 真实百分比 + 步骤 + 进度条。
class ImportLoadingView extends StatelessWidget {
  const ImportLoadingView({super.key, required this.state});

  final ImportState state;

  String _stepLabel(BuildContext context) {
    switch (state.step) {
      case ImportStep.reading:
        return context.l10n.stepReading;
      case ImportStep.decrypting:
        return context.l10n.stepDecrypting;
      case ImportStep.indexing:
        return context.l10n.stepIndexing;
      case ImportStep.done:
        return context.l10n.stepDone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MXPulseGrid(),
        const SizedBox(height: 20),
        Text(
          state.fileLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: tokens.text,
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          "${state.percent}%",
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: tokens.accent,
            height: 1,
            fontFamilyFallback: MXTheme.monoFontFallback,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _stepLabel(context),
          style: TextStyle(fontSize: 12.5, color: tokens.muted),
        ),
        const SizedBox(height: 14),
        // 设计稿 width:min(300px,90%)：手机上卡片内宽不足 300，定宽会溢出
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.hasBoundedWidth
                ? math.min(300, constraints.maxWidth * 0.9)
                : 300;
            return SizedBox(
              width: width,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: state.percent / 100,
                  minHeight: 4,
                  backgroundColor: tokens.panel2,
                  color: tokens.accent,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
