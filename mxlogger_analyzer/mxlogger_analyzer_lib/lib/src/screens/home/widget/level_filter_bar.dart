import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/level/mx_level.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';

/// 等级分布条 + 等级筛选 chips（对齐设计稿）。
/// 分布条按各等级条数占比分段，点击段/chip 均可切换过滤；
/// 有选中时未选中的段与 chip 降透明度。
class LevelFilterBar extends MXConsumerWidget {
  const LevelFilterBar({super.key});

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final Map<int, int> counts = ref.watch(ref.store.levelCounts).valueOrNull ?? const {};
    final LogFilterState filter = ref.watch(ref.store.filter);

    void toggle(int level) {
      ref.store.filter.update((LogFilterState state) => state.toggleLevel(level));
    }

    final double padX = context.mxPadX;
    final bool mobile = context.isMobileLayout;

    final List<Widget> chips = [
      for (final int level in mxAllLevels)
        _LevelChip(
          level: level,
          count: counts[level] ?? 0,
          selected: filter.levels.contains(level),
          dimmed: filter.levels.isNotEmpty && !filter.levels.contains(level),
          onTap: () => toggle(level),
        ),
    ];

    // 左右留白在内部处理：移动端 chips 需要铺到屏幕边缘横向滚动，
    // 故不能由父级 header 统一加 padding
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padX),
          child: _distributionBar(context, tokens, counts, filter, toggle),
        ),
        const SizedBox(height: 8),
        // 移动端 5 个 chips 换行会顶掉半屏，改为单行横向滚动（设计稿 level-bar）
        if (mobile)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(padX, 0, padX, 2),
            child: Row(
              children: [
                for (int i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  chips[i],
                ],
              ],
            ),
          )
        else
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padX),
            child: Wrap(spacing: 6, runSpacing: 6, children: chips),
          ),
      ],
    );
  }

  /// 6px 高分段分布条，无数据的等级不占段
  Widget _distributionBar(
    BuildContext context,
    MXTokens tokens,
    Map<int, int> counts,
    LogFilterState filter,
    void Function(int level) onToggle,
  ) {
    final int total = counts.values.fold(0, (int sum, int c) => sum + c);
    final List<int> present =
        mxAllLevels.where((int level) => (counts[level] ?? 0) > 0).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: total == 0
            ? Container(color: tokens.panel2)
            : Row(
                children: [
                  for (final int level in present)
                    Expanded(
                      flex: counts[level] ?? 0,
                      child: _DistSegment(
                        color: tokens.levelColor(level),
                        dimmed: filter.levels.isNotEmpty && !filter.levels.contains(level),
                        tooltip: _distTip(context, level, counts[level] ?? 0, total),
                        onTap: () => onToggle(level),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  String _distTip(BuildContext context, int level, int count, int total) {
    final double pct = count / total * 100;
    final String pctText = pct < 1 ? "<1" : pct.toStringAsFixed(pct < 10 ? 1 : 0);
    return context.l10n.distTip(mxLevelName(level), "$count", pctText);
  }
}

class _DistSegment extends StatefulWidget {
  const _DistSegment({
    required this.color,
    required this.dimmed,
    required this.tooltip,
    required this.onTap,
  });

  final Color color;
  final bool dimmed;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_DistSegment> createState() => _DistSegmentState();
}

class _DistSegmentState extends State<_DistSegment> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final double opacity = widget.dimmed ? 0.22 : (_hovering ? 0.8 : 1.0);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 150),
            child: Container(
              constraints: const BoxConstraints(minWidth: 3),
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// 等级筛选 chip：8x8 色块 + 等级名 + 紧凑计数。
class _LevelChip extends StatefulWidget {
  const _LevelChip({
    required this.level,
    required this.count,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final int level;
  final int count;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  State<_LevelChip> createState() => _LevelChipState();
}

class _LevelChipState extends State<_LevelChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Color color = tokens.levelColor(widget.level);
    final Color borderColor =
        widget.selected || _hovering ? color : tokens.border;
    final Color bg = widget.selected
        ? Color.alphaBlend(color.withValues(alpha: 0.12), tokens.panel)
        : tokens.panel;

    return Tooltip(
      message: context.l10n.levelCountTip("${widget.count}"),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedOpacity(
            opacity: widget.dimmed ? 0.38 : 1,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              // 移动端上下加高到可点尺寸（设计稿 lv-chip padding 7px）
              padding: context.isMobileLayout
                  ? const EdgeInsets.fromLTRB(9, 7, 12, 7)
                  : const EdgeInsets.fromLTRB(9, 5, 12, 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    mxLevelName(widget.level),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: widget.selected ? tokens.text : tokens.muted,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mxFmtCount(widget.count),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                      fontFamilyFallback: MXTheme.monoFontFallback,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
