import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';

/// 生效筛选条件 chips 行：时间范围（tag / name 已迁入搜索框内的 chip）。
/// 单个可移除，或「全部清除」。
class ActiveFilters extends MXConsumerWidget {
  const ActiveFilters({super.key});

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final LogFilterState filter = ref.watch(ref.store.filter);

    final List<Widget> chips = [];
    if (filter.timeActive) {
      String timeOf(int? us) =>
          us == null ? "…" : mxFmtTs(DateTime.fromMicrosecondsSinceEpoch(us)).full;
      chips.add(_FilterChip(
        type: context.l10n.filterTypeTime,
        label: "${timeOf(filter.fromUs)} → ${timeOf(filter.toUs)}",
        onRemove: () => ref.store.filter
            .update((LogFilterState state) => state.copyWith(fromUs: null, toUs: null)),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.mxPadX, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.bg,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.l10n.filterLabel, style: TextStyle(fontSize: 12, color: tokens.faint)),
          ...chips,
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () =>
                  ref.store.filter.update((LogFilterState state) => state.clearAll()),
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  context.l10n.clearAllFilters,
                  style: TextStyle(fontSize: 12, color: tokens.lvError),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.type, required this.label, required this.onRemove});

  final String type;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
      decoration: BoxDecoration(
        color: tokens.panel2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type, style: TextStyle(fontSize: 12, color: tokens.muted)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: tokens.text,
              fontFamilyFallback: MXTheme.monoFontFallback,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: context.l10n.removeFilterTip,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    "×",
                    style: TextStyle(fontSize: 13, color: tokens.muted, height: 1),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
