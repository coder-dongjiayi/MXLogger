import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';

/// 多组解密参数编辑器（向导第二步与「确认解密参数」弹框共用）。
///
/// 每组一行：勾选框 + KEY + IV + 拖拽把手 + 删除。勾选的组按自上而下的顺序
/// 参与解密——先用第一组解，解不开自动换下一组，依此类推（序号即尝试顺序，
/// 画在勾选框里），故「排序」就是调整尝试顺序，按住把手上下拖动即可。
/// 可以全部删空：一组都没有就是「不解密」，用「添加一组」按钮再加回来。
/// 内部持有输入控制器，变更即通过 [onChanged] 回吐整表，由调用方决定何时落库。
class CryptEntryList extends StatefulWidget {
  const CryptEntryList({
    super.key,
    required this.initialEntries,
    required this.onChanged,
    this.maxHeight,
  });

  /// 初始值；后续编辑由本组件自持，不随外部状态回灌（避免打字时光标被重置）
  final List<CryptEntry> initialEntries;

  final ValueChanged<List<CryptEntry>> onChanged;

  /// 列表限高（弹框内用），超出则内部滚动
  final double? maxHeight;

  @override
  State<CryptEntryList> createState() => _CryptEntryListState();
}

class _CryptEntryListState extends State<CryptEntryList> {
  final List<_EntryRow> _rows = [];

  @override
  void initState() {
    super.initState();
    // 没有历史配置就一行都不给：空表即「日志未加密」，用户需要时自己加
    _rows.addAll(widget.initialEntries.map(_EntryRow.new));
  }

  @override
  void dispose() {
    for (final _EntryRow row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_rows.map((_EntryRow row) => row.toEntry()).toList());
  }

  void _add() {
    setState(() => _rows.add(_EntryRow(const CryptEntry())));
    _emit();
  }

  void _remove(int index) {
    setState(() => _rows.removeAt(index).dispose());
    _emit();
  }

  /// 拖拽排序：顺序即解密尝试顺序，故拖完要回吐整表
  /// （onReorderItem 给的 newIndex 已按「移走 oldIndex 之后」折算过，直接插即可）
  void _reorder(int oldIndex, int newIndex) {
    setState(() => _rows.insert(newIndex, _rows.removeAt(oldIndex)));
    _emit();
  }

  void _toggle(int index) {
    setState(() => _rows[index].enabled = !_rows[index].enabled);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final List<int?> orders = _orders();

    // 拖拽把手排序：itemBuilder 是惰性调用的，序号先整表算好再取用
    final Widget list = ReorderableListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      // 限高时列表自己滚，不限高时高度由内容决定、交给外层页面滚
      physics: widget.maxHeight == null
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      // 把手之外的地方（尤其是 KEY / IV 输入框）不该触发拖拽
      buildDefaultDragHandles: false,
      itemCount: _rows.length,
      onReorderItem: _reorder,
      proxyDecorator: _dragProxy,
      itemBuilder: (BuildContext context, int index) => Padding(
        key: ObjectKey(_rows[index]),
        padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
        child: _row(tokens, index, orders[index]),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_rows.isEmpty)
          const SizedBox.shrink()
        else if (widget.maxHeight != null)
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight!),
            child: list,
          )
        else
          list,
        if (_rows.isNotEmpty) const SizedBox(height: 10),
        Row(
          children: [
            _AddButton(label: context.l10n.addCryptGroup, onTap: _add),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                // 一组都没有时说明「不解密」，否则讲清多组的尝试顺序
                _rows.isEmpty
                    ? context.l10n.cryptGroupEmptyHint
                    : context.l10n.cryptGroupOrderHint,
                style: TextStyle(fontSize: 11, height: 1.5, color: tokens.faint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 每行在勾选框里显示的「第几个尝试」：只对勾选的组连续编号，未勾选为 null
  List<int?> _orders() {
    int order = 0;
    return _rows.map((_EntryRow row) {
      if (!row.enabled) return null;
      order = order + 1;
      return order;
    }).toList(growable: false);
  }

  /// 拖起来的那一行：略微放大 + 投影，与静止的行区分开
  Widget _dragProxy(Widget child, int index, Animation<double> animation) {
    final MXTokens tokens = MXTokens.of(context);
    return Material(
      color: Colors.transparent,
      child: Transform.scale(
        scale: 1.02,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: tokens.mask,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _row(MXTokens tokens, int index, int? order) {
    final _EntryRow row = _rows[index];
    final bool mobile = context.isMobileLayout;
    final Widget keyField = _CryptInput(
      label: context.l10n.keyLabel,
      hint: context.l10n.keyHint,
      controller: row.keyController,
      onChanged: (_) => _emit(),
    );
    final Widget ivField = _CryptInput(
      label: context.l10n.ivLabel,
      hint: context.l10n.ivHint,
      controller: row.ivController,
      onChanged: (_) => _emit(),
    );
    final Widget checkbox = _OrderCheckbox(
      order: order,
      onTap: () => _toggle(index),
      tooltip: context.l10n.cryptGroupToggleTip,
    );
    // 顺序即解密尝试顺序：按住把手上下拖动调整（只有多于一组时才有意义）
    final bool sortable = _rows.length > 1;
    final Widget handle =
        _DragHandle(index: index, tooltip: context.l10n.reorderCryptGroup);

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 9, 5, 9),
      decoration: BoxDecoration(
        color: row.enabled ? tokens.panel2 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.enabled ? tokens.accent.withValues(alpha: 0.35) : tokens.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 手机屏窄：把手竖着叠在勾选框下面，省出的横向空间留给 KEY / IV
          if (mobile && sortable)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [checkbox, const SizedBox(height: 4), handle],
            )
          else
            checkbox,
          const SizedBox(width: 9),
          Expanded(
            // 手机屏窄：KEY / IV 各占一行，并排会挤到不可用
            child: mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [keyField, const SizedBox(height: 6), ivField],
                  )
                : Row(
                    children: [
                      Expanded(child: keyField),
                      const SizedBox(width: 8),
                      Expanded(child: ivField),
                    ],
                  ),
          ),
          const SizedBox(width: 2),
          if (!mobile && sortable) handle,
          // 任意一组都能删，删空即按未加密解析
          _RemoveButton(
            tooltip: context.l10n.removeCryptGroup,
            onTap: () => _remove(index),
          ),
        ],
      ),
    );
  }
}

/// 一行的可变状态（输入控制器 + 勾选态）
class _EntryRow {
  _EntryRow(CryptEntry entry)
      : keyController = TextEditingController(text: entry.cryptKey),
        ivController = TextEditingController(text: entry.cryptIv),
        enabled = entry.enabled;

  final TextEditingController keyController;
  final TextEditingController ivController;
  bool enabled;

  CryptEntry toEntry() => CryptEntry(
        cryptKey: keyController.text,
        cryptIv: ivController.text,
        enabled: enabled,
      );

  void dispose() {
    keyController.dispose();
    ivController.dispose();
  }
}

/// 勾选框兼顺序标记：勾选的组显示它是第几个被尝试的，未勾选留空。
class _OrderCheckbox extends StatelessWidget {
  const _OrderCheckbox({required this.order, required this.onTap, required this.tooltip});

  final int? order;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool checked = order != null;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: checked ? tokens.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: checked ? tokens.accent : tokens.faint),
            ),
            alignment: Alignment.center,
            child: checked
                ? Text(
                    "$order",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: tokens.onAccent,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// 组内 KEY / IV 输入（标签在左的描边输入框，与向导原样式一致）
class _CryptInput extends StatefulWidget {
  const _CryptInput({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<_CryptInput> createState() => _CryptInputState();
}

class _CryptInputState extends State<_CryptInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final double fontSize = context.mxInputFontSize(12.5);
    return Focus(
      onFocusChange: (bool value) => setState(() => _focused = value),
      child: Container(
        padding: const EdgeInsets.only(left: 9),
        decoration: BoxDecoration(
          color: tokens.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _focused ? tokens.accent : tokens.border),
        ),
        child: Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.55,
                color: tokens.faint,
                fontFamilyFallback: MXTheme.monoFontFallback,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                maxLength: 16,
                style: TextStyle(
                  fontSize: fontSize,
                  color: tokens.text,
                  fontFamilyFallback: MXTheme.monoFontFallback,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  counterText: "",
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontSize: fontSize,
                    color: tokens.faint.withValues(alpha: 0.7),
                  ),
                  contentPadding: const EdgeInsets.only(top: 8, bottom: 8, right: 9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「添加一组」描边小按钮
class _AddButton extends StatefulWidget {
  const _AddButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color color = _hovering ? tokens.accent : tokens.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hovering ? tokens.accent : tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 组尾的拖拽把手：按住上下拖动调整该组的解密尝试顺序。
/// 只在把手上响应拖拽（buildDefaultDragHandles: false），
/// 免得拖动输入框选文字时把整行拖走。
class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index, required this.tooltip});

  final int index;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final double size = context.isMobileLayout ? 30 : 24;
    return Tooltip(
      message: tooltip,
      child: ReorderableDragStartListener(
        index: index,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(Icons.drag_indicator, size: 15, color: tokens.faint),
          ),
        ),
      ),
    );
  }
}

/// 组尾的删除按钮：hover 变错误色
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final double size = context.isMobileLayout ? 30 : 24;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.close,
              size: 14,
              color: _hovering ? tokens.lvError : tokens.faint,
            ),
          ),
        ),
      ),
    );
  }
}
