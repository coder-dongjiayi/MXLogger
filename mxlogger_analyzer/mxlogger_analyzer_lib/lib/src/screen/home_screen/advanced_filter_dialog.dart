import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/component/mx_hoverable.dart';
import 'package:mxlogger_analyzer_lib/src/provider/advanced_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

Future<void> showAdvancedFilterDialog(BuildContext context) {
  return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) {
        return ProviderScope(
          parent: ProviderScope.containerOf(context),
          child: const AdvancedFilterDialog(),
        );
      });
}

class AdvancedFilterDialog extends ConsumerWidget {
  const AdvancedFilterDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdvancedFilter filter = ref.watch(advancedFilterProvider);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 660,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: MXTheme.themeColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MXTheme.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(enabledCount: filter.enabledCount),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    children: [
                      _FilterSection(
                        type: FilterListType.white,
                        rules: filter.whitelist,
                      ),
                      const SizedBox(height: 18),
                      _FilterSection(
                        type: FilterListType.black,
                        rules: filter.blacklist,
                      ),
                    ],
                  ),
                ),
              ),
              const _Footer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.enabledCount});

  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: MXTheme.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 20, color: MXTheme.info),
          const SizedBox(width: 10),
          Text("高级过滤器",
              style: TextStyle(
                  color: MXTheme.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          if (enabledCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: MXTheme.info.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("$enabledCount 条生效",
                  style: TextStyle(color: MXTheme.info, fontSize: 12)),
            ),
          const Spacer(),
          _IconAction(
            icon: Icons.close_rounded,
            tooltip: "关闭",
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(mxLogDataSourceProvider);
    final int matched = asyncData.valueOrNull?.dataSource.length ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 16),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: MXTheme.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt_outlined, size: 15, color: MXTheme.subText),
          const SizedBox(width: 6),
          Text(
            asyncData.isLoading ? "正在筛选…" : "当前匹配 $matched 条日志",
            style: TextStyle(color: MXTheme.subText, fontSize: 13),
          ),
          const Spacer(),
          _TextButton(
            label: "全部清空",
            onTap: () => ref.read(advancedFilterProvider.notifier).clearAll(),
          ),
          const SizedBox(width: 10),
          _TextButton(
            label: "完成",
            primary: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// 白名单 / 黑名单其中一块：标题 + 输入行 + 规则 chips
class _FilterSection extends ConsumerStatefulWidget {
  const _FilterSection({required this.type, required this.rules});

  final FilterListType type;
  final List<FilterRule> rules;

  @override
  ConsumerState<_FilterSection> createState() => _FilterSectionState();
}

class _FilterSectionState extends ConsumerState<_FilterSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  FilterField _field = FilterField.all;

  bool get _isWhite => widget.type == FilterListType.white;

  Color get _accent => _isWhite ? MXTheme.debug : MXTheme.error;

  String get _title => _isWhite ? "白名单" : "黑名单";

  String get _subtitle => _isWhite ? "只保留命中的日志" : "排除命中的日志";

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    ref
        .read(advancedFilterProvider.notifier)
        .add(widget.type, keyword: keyword, field: _field);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final int enabled = widget.rules.where((e) => e.enabled).length;
    final bool allEnabled =
        widget.rules.isNotEmpty && enabled == widget.rules.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: MXTheme.itemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: _accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(_title,
                  style: TextStyle(
                      color: MXTheme.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(_subtitle,
                  style: TextStyle(color: MXTheme.subText, fontSize: 12)),
              const Spacer(),
              if (widget.rules.isNotEmpty) ...[
                Text("$enabled/${widget.rules.length}",
                    style: TextStyle(color: MXTheme.subText, fontSize: 12)),
                const SizedBox(width: 10),
                _TextButton(
                  label: allEnabled ? "全不选" : "全选",
                  dense: true,
                  onTap: () => ref
                      .read(advancedFilterProvider.notifier)
                      .toggleAll(widget.type, !allEnabled),
                ),
                const SizedBox(width: 6),
                _TextButton(
                  label: "清空",
                  dense: true,
                  onTap: () => ref
                      .read(advancedFilterProvider.notifier)
                      .clear(widget.type),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          _inputRow(),
          const SizedBox(height: 12),
          _rules(),
        ],
      ),
    );
  }

  Widget _inputRow() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: MXTheme.sliderColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MXTheme.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          ...FilterField.values.map((field) => _fieldTab(field)),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: MXTheme.white.withOpacity(0.08),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(color: MXTheme.white, fontSize: 14),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: _field == FilterField.all
                    ? "输入关键词，回车添加"
                    : "输入要匹配的 ${_field.label} 内容，回车添加",
                hintStyle: TextStyle(color: MXTheme.subText, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconAction(
            icon: Icons.add_rounded,
            tooltip: "添加到$_title",
            color: _accent,
            onTap: _submit,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  /// 字段选择：全部 / tag / name / msg
  Widget _fieldTab(FilterField field) {
    final bool selected = _field == field;
    return MXHoverable(
      onTap: () => setState(() => _field = field),
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withOpacity(0.25)
              : (hovered ? MXTheme.white.withOpacity(0.06) : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          field.label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? MXTheme.white : MXTheme.subText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _rules() {
    if (widget.rules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          _isWhite ? "还没有白名单规则，添加后只显示命中的日志" : "还没有黑名单规则，添加后命中的日志会被隐藏",
          style: TextStyle(color: MXTheme.subText, fontSize: 12),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.rules
          .map((rule) => _RuleChip(
                key: ValueKey(rule.identity),
                rule: rule,
                accent: _accent,
                onTap: () => ref
                    .read(advancedFilterProvider.notifier)
                    .toggle(widget.type, rule),
                onRemove: () => ref
                    .read(advancedFilterProvider.notifier)
                    .remove(widget.type, rule),
              ))
          .toList(),
    );
  }
}

/// 单条规则。整体点击切换启用状态，右侧 × 删除。
class _RuleChip extends StatelessWidget {
  const _RuleChip({
    Key? key,
    required this.rule,
    required this.accent,
    required this.onTap,
    required this.onRemove,
  }) : super(key: key);

  final FilterRule rule;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final bool enabled = rule.enabled;
    return MXHoverable(
      onTap: onTap,
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.only(left: 8, right: 4, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: enabled
              ? accent.withOpacity(hovered ? 0.3 : 0.22)
              : (hovered
                  ? MXTheme.white.withOpacity(0.06)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? accent.withOpacity(0.9)
                : MXTheme.white.withOpacity(hovered ? 0.25 : 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: enabled ? accent : MXTheme.subText,
            ),
            const SizedBox(width: 6),
            if (rule.field != FilterField.all) ...[
              Text("${rule.field.label}:",
                  style: TextStyle(
                      color: enabled
                          ? MXTheme.info
                          : MXTheme.subText.withOpacity(0.8),
                      fontSize: 13)),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                rule.keyword,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: enabled ? MXTheme.white : MXTheme.subText,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 2),
            _IconAction(
              icon: Icons.close_rounded,
              size: 13,
              tooltip: "删除该规则",
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.size = 18,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget child = MXHoverable(
      onTap: onTap,
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: hovered
              ? (color ?? MXTheme.white).withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: size,
            color: hovered ? (color ?? MXTheme.white) : MXTheme.subText),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({
    required this.label,
    required this.onTap,
    this.primary = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return MXHoverable(
      onTap: onTap,
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: dense
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? MXTheme.buttonColor.withOpacity(hovered ? 1 : 0.85)
              : (hovered ? MXTheme.white.withOpacity(0.08) : Colors.transparent),
          borderRadius: BorderRadius.circular(8),
          border: primary
              ? null
              : Border.all(color: MXTheme.white.withOpacity(0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: primary || hovered ? MXTheme.white : MXTheme.subText,
            fontSize: dense ? 12 : 13,
          ),
        ),
      ),
    );
  }
}
