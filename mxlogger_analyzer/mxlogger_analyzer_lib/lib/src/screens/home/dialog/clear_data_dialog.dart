import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';

/// 清空数据二次确认弹框；返回 true 表示用户确认清空。
Future<bool?> showClearDataDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    // 就近 Navigator：嵌入模式下主题 / l10n 在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    builder: (BuildContext context) => const _ClearDataDialog(),
  );
}

class _ClearDataDialog extends StatelessWidget {
  const _ClearDataDialog();

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Dialog(
      backgroundColor: tokens.panel,
      elevation: 0,
      // 手机屏幕窄，缩小外边距给内容让位
      insetPadding: context.isMobileLayout
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tokens.lvError.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.lvError.withValues(alpha: 0.4)),
                    ),
                    child: Icon(Icons.delete_outline, size: 19, color: tokens.lvError),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.clearDataConfirmTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.clearDataConfirmMessage,
                style: TextStyle(fontSize: 13, height: 1.7, color: tokens.muted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: context.l10n.cancel,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: context.l10n.confirmClear,
                    danger: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹框按钮：默认描边次级样式，[danger] 为危险色实底（清空）。
class _DialogButton extends StatefulWidget {
  const _DialogButton({required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color bg;
    final Color fg;
    Color borderColor;
    if (widget.danger) {
      bg = _hovering
          ? Color.alphaBlend(Colors.white.withValues(alpha: 0.1), tokens.lvError)
          : tokens.lvError;
      fg = Colors.white;
      borderColor = Colors.transparent;
    } else {
      bg = _hovering ? tokens.panel2 : Colors.transparent;
      fg = _hovering ? tokens.text : tokens.muted;
      borderColor = _hovering ? tokens.faint : tokens.border;
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }
}
