import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_support_dialog.dart';

/// 工具栏里的「支持作者」入口，窄窗口只保留咖啡图标。
class MXSupportButton extends StatelessWidget {
  const MXSupportButton({super.key, this.size = 30, this.compact = false});

  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final String label = context.l10n.supportAuthor;
    final Widget button = OutlinedButton(
      onPressed: () => showSupportAuthorDialog(context),
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(compact ? size : 0, size)),
        padding: WidgetStatePropertyAll(
          compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: WidgetStatePropertyAll(tokens.lvWarning),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          final bool highlight =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed);
          return Color.alphaBlend(
            tokens.lvWarning.withValues(alpha: highlight ? 0.14 : 0.05),
            tokens.panel,
          );
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final bool highlight =
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused) ||
              states.contains(WidgetState.pressed);
          return BorderSide(
            color: tokens.lvWarning.withValues(alpha: highlight ? 0.9 : 0.45),
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge!.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        animationDuration: const Duration(milliseconds: 120),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.coffee_outlined,
            size: 16,
            semanticLabel: compact ? label : null,
          ),
          if (!compact) ...[const SizedBox(width: 7), Text(label)],
        ],
      ),
    );
    return compact
        ? Tooltip(message: label, excludeFromSemantics: true, child: button)
        : button;
  }
}
