import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/crypt_entry_list.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

/// 管理当前配置的解密 KEY / IV（桌面端 header 钥匙按钮入口）：
/// 与导入前的「确认解密参数」弹框共用同一张编辑表——可增删、勾选、拖动排序，
/// 勾选的组按序号依次尝试解密。已保存的组掩码显示且不可编辑，改参数删掉重加。
/// 「应用」保存参数；数据页已有导入过的文件时顺带用新参数重新解析它们
/// （重解析的成功 / 失败提示由 MainScreen 统一消费）。取消则不动已保存的参数。
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

class _KeyIvDialog extends MXConsumerStatefulWidget {
  const _KeyIvDialog();

  @override
  MXConsumerState<_KeyIvDialog> createState() => _KeyIvDialogState();
}

class _KeyIvDialogState extends MXConsumerState<_KeyIvDialog> {
  /// 编辑中的解密参数组（应用时才落库，取消不改动设置）
  late List<CryptEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = store.crypt.value.entries;
  }

  /// 与 [CryptStore.saveEntries] 同样的清洗规则，用于和已保存的参数比对是否有改动
  List<CryptEntry> _cleaned(List<CryptEntry> entries) => entries
      .map((CryptEntry entry) => entry.trimmed())
      .where((CryptEntry entry) => !entry.isEmpty)
      .toList();

  void _apply() {
    final List<CryptEntry> next = _cleaned(_entries);
    final bool changed = !listEquals(next, store.crypt.value.entries);
    if (changed) store.crypt.saveEntries(next);
    // 参数变了且手上还有上一批文件：直接用新参数重解析，省得用户再导一次
    final bool reparse = changed && store.importer.canReparse;
    // toast 落在宿主 root overlay 里，先弹再关弹框不影响它的显示
    if (changed && !reparse) showMXToast(context, context.l10n.keyIvUpdated);
    Navigator.of(context).pop();
    if (reparse) store.importer.reparse();
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
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
              Text(
                context.l10n.keyIvNote,
                style: TextStyle(fontSize: 12.5, height: 1.7, color: tokens.muted),
              ),
              const SizedBox(height: 14),
              // 多组解密参数：勾选的组按序号依次尝试；组多了列表内部滚动
              CryptEntryList(
                initialEntries: _entries,
                maxHeight: 300,
                onChanged: (List<CryptEntry> entries) => _entries = entries,
              ),
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
                    // 有上一批文件才谈得上「重新解析」，否则只是保存参数
                    label: store.importer.canReparse
                        ? context.l10n.applyReparse
                        : context.l10n.apply,
                    primary: true,
                    onTap: _apply,
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
