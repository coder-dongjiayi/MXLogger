import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/crypt_entry_list.dart';

/// 选择 .mx 文件后、解析前的解密参数确认弹框：
/// 代入上次配置的各组 Key/IV（可增删、勾选，勾选的按序号依次尝试），
/// 并可勾选「导入前清空已有数据」。
/// 确认（并保存解密参数）返回结果，取消返回 null（不改动已保存的参数）。
typedef CryptConfirmResult = ({bool clearExisting});

Future<CryptConfirmResult?> showCryptConfirmDialog(BuildContext context) {
  final MXTokens tokens = MXTokens.of(context);
  return showDialog<CryptConfirmResult>(
    context: context,
    barrierColor: tokens.mask,
    // 就近 Navigator：嵌入模式下 MXScope / 主题 / l10n 在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    builder: (BuildContext context) => const _CryptConfirmDialog(),
  );
}

class _CryptConfirmDialog extends MXConsumerStatefulWidget {
  const _CryptConfirmDialog();

  @override
  MXConsumerState<_CryptConfirmDialog> createState() => _CryptConfirmDialogState();
}

class _CryptConfirmDialogState extends MXConsumerState<_CryptConfirmDialog> {
  /// 编辑中的解密参数组（确认时才落库，取消不改动设置）
  late List<CryptEntry> _entries;

  /// 默认不清空（与已有数据合并），勾选后仅保留本次导入
  bool _clearExisting = false;

  @override
  void initState() {
    super.initState();
    _entries = store.crypt.value.entries;
  }

  void _confirm() {
    store.crypt.saveEntries(_entries);
    Navigator.of(context).pop((clearExisting: _clearExisting));
  }

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
                    context.l10n.cryptConfirmTitle,
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
                context.l10n.cryptConfirmNote,
                style: TextStyle(fontSize: 12.5, height: 1.7, color: tokens.muted),
              ),
              const SizedBox(height: 16),
              // 多组解密参数：勾选的组按序号依次尝试
              CryptEntryList(
                initialEntries: _entries,
                // 弹框高度有限，组多了内部滚动
                maxHeight: 240,
                onChanged: (List<CryptEntry> entries) => _entries = entries,
              ),
              const SizedBox(height: 16),
              _clearOption(tokens),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: context.l10n.cancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: context.l10n.startImport,
                    primary: true,
                    onTap: _confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「导入前清空已有数据」复选项：勾选替换、否则与已有数据合并
  Widget _clearOption(MXTokens tokens) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _clearExisting = !_clearExisting),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 18,
              height: 18,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: _clearExisting ? tokens.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _clearExisting ? tokens.accent : tokens.faint,
                ),
              ),
              alignment: Alignment.center,
              child: _clearExisting
                  ? Icon(Icons.check, size: 12, color: tokens.onAccent)
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.clearExistingData,
                    style: TextStyle(fontSize: 12.5, color: tokens.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.clearExistingDataHint,
                    style: TextStyle(fontSize: 11, height: 1.5, color: tokens.faint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹框按钮：默认描边次级样式，[primary] 为强调色实底。
class _DialogButton extends StatefulWidget {
  const _DialogButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

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
    if (widget.primary) {
      bg = _hovering
          ? Color.alphaBlend(Colors.white.withValues(alpha: 0.1), tokens.accent)
          : tokens.accent;
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
