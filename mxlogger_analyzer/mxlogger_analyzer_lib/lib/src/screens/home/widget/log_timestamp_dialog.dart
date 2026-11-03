import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 展示文件中的原始微秒时间戳。
Future<void> showLogTimestampDialog(
  BuildContext context, {
  required LogModel log,
}) {
  final MXTokens tokens = MXTokens.of(context);
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    barrierColor: tokens.mask,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: tokens.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.border),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      scrollable: true,
      title: Text(
        context.l10n.timestampTitle,
        style: TextStyle(fontSize: 16, color: tokens.text),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.timestampRaw,
              style: TextStyle(fontSize: 12.5, color: tokens.muted),
            ),
            const SizedBox(height: 6),
            SelectableText(
              log.timestamp.toString(),
              style: TextStyle(
                fontSize: 14,
                color: tokens.text,
                fontFamilyFallback: MXTheme.monoFontFallback,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
}
