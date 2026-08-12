import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

/// 查看当前配置的解密 KEY / IV（桌面端 header 钥匙按钮入口）。
/// 只读展示：勾选的组带解密尝试顺序编号，未勾选的灰显；点击值即复制。
Future<void> showKeyIvDialog(BuildContext context) {
  final MXTokens tokens = MXTokens.of(context);
  return showDialog<void>(
    context: context,
    barrierColor: tokens.mask,
    // 就近 Navigator：嵌入模式下主题 / l10n 在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    builder: (BuildContext context) => const _KeyIvDialog(),
  );
}

class _KeyIvDialog extends MXConsumerWidget {
  const _KeyIvDialog();

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final List<CryptEntry> entries = ref.watch(ref.store.crypt).entries;

    // 编号只对勾选的组连续计（与设置表的顺序勾选框一致）
    int order = 0;
    final List<Widget> rows = [];
    for (final CryptEntry entry in entries) {
      if (entry.enabled) order = order + 1;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(_EntryRow(entry: entry, order: entry.enabled ? order : null));
    }

    return Dialog(
      backgroundColor: tokens.panel,
      elevation: 0,
      insetPadding: context.isMobileLayout
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tokens.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
                      color: tokens.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
                    ),
                    child: Icon(Icons.key_outlined, size: 19, color: tokens.accent),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n.keyIvDialogTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      context.l10n.keyIvEmpty,
                      style: TextStyle(fontSize: 12.5, color: tokens.faint),
                    ),
                  ),
                )
              else ...[
                Text(
                  context.l10n.keyIvNote,
                  style: TextStyle(fontSize: 12.5, height: 1.7, color: tokens.muted),
                ),
                const SizedBox(height: 12),
                // 组多时内部滚动，不把弹框撑出屏幕
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rows,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: _CloseButton(
                  label: context.l10n.close,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 一组解密参数（只读）：顺序标记 + KEY / IV 两行，点击值复制。
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.order});

  final CryptEntry entry;

  /// 解密尝试顺序（1 起）；null 表示该组未勾选
  final int? order;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool enabled = order != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: enabled ? tokens.panel2 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: enabled ? tokens.accent.withValues(alpha: 0.35) : tokens.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 顺序标记：与设置表的勾选框视觉一致（未勾选显示「未启用」灰标）
          if (enabled)
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                "$order",
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: tokens.onAccent,
                ),
              ),
            )
          else
            Text(
              context.l10n.keyIvDisabled,
              style: TextStyle(fontSize: 10.5, color: tokens.faint),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ValueLine(label: "KEY", value: entry.cryptKey, dimmed: !enabled),
                const SizedBox(height: 4),
                _ValueLine(label: "IV", value: entry.cryptIv, dimmed: !enabled),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// KEY / IV 单行值：等宽字体展示，点击复制到剪贴板。
class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.label, required this.value, required this.dimmed});

  final String label;
  final String value;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Tooltip(
      message: context.l10n.clickToCopy,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) showMXToast(context, context.l10n.copied);
          },
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.55,
                    color: tokens.faint,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: dimmed ? tokens.faint : tokens.text,
                    fontFamilyFallback: MXTheme.monoFontFallback,
                  ),
                ),
              ),
              Icon(Icons.copy_outlined, size: 12, color: tokens.faint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部关闭按钮（描边次级样式，与其它弹框按钮一致）。
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
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
            color: _hovering ? tokens.panel2 : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _hovering ? tokens.faint : tokens.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}
