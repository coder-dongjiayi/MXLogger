import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';

/// 确认后在弹框内等待清空，返回 true 表示操作已完成。
Future<bool?> showClearDataDialog(
  BuildContext context, {
  required Future<void> Function() onClear,
}) {
  return showDialog<bool>(
    context: context,
    // 就近 Navigator：嵌入模式下主题 / l10n 在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    builder: (BuildContext context) => _ClearDataDialog(onClear: onClear),
  );
}

class _ClearDataDialog extends StatefulWidget {
  const _ClearDataDialog({required this.onClear});

  final Future<void> Function() onClear;

  @override
  State<_ClearDataDialog> createState() => _ClearDataDialogState();
}

class _ClearDataDialogState extends State<_ClearDataDialog> {
  bool _clearing = false;
  bool _failed = false;

  Future<void> _clear() async {
    if (_clearing) return;
    setState(() {
      _clearing = true;
      _failed = false;
    });
    // 先呈现 loading，再开始可能耗时的数据库操作。
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    try {
      await widget.onClear();
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clearing = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final message = _clearing
        ? context.l10n.clearingData
        : _failed
        ? context.l10n.clearDataFailed
        : context.l10n.clearDataConfirmMessage;
    return PopScope(
      canPop: !_clearing,
      child: Dialog(
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
                        border: Border.all(
                          color: tokens.lvError.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 19,
                        color: tokens.lvError,
                      ),
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
                Semantics(
                  liveRegion: true,
                  label: message,
                  excludeSemantics: true,
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: _failed ? tokens.lvError : tokens.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      label: context.l10n.cancel,
                      onTap: _clearing
                          ? null
                          : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 8),
                    _DialogButton(
                      label: context.l10n.confirmClear,
                      danger: true,
                      loading: _clearing,
                      onTap: _clearing ? null : _clear,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 弹框按钮：默认描边次级样式，[danger] 为危险色实底（清空）。
class _DialogButton extends StatefulWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool loading;

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
          ? Color.alphaBlend(
              Colors.white.withValues(alpha: 0.1),
              tokens.lvError,
            )
          : tokens.lvError;
      fg = Colors.white;
      borderColor = Colors.transparent;
    } else {
      bg = _hovering ? tokens.panel2 : Colors.transparent;
      fg = _hovering ? tokens.text : tokens.muted;
      borderColor = _hovering ? tokens.faint : tokens.border;
    }
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.loading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: widget.onTap == null && !widget.loading
                        ? fg.withValues(alpha: 0.5)
                        : fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
