import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 30x30 描边小图标按钮（对齐设计稿 header 操作按钮）：
/// panel 底 + border 描边，hover 变强调色；[active] 常亮强调色。
class MXIconButton extends StatefulWidget {
  const MXIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
    this.size = 30,
    this.iconSize = 14,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;
  final double size;
  final double iconSize;

  @override
  State<MXIconButton> createState() => _MXIconButtonState();
}

class _MXIconButtonState extends State<MXIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool highlight = _hovering || widget.active;
    final Color color = highlight ? tokens.accent : tokens.muted;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: tokens.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: highlight ? tokens.accent : tokens.border),
            ),
            alignment: Alignment.center,
            child: IconTheme(
              data: IconThemeData(color: color, size: widget.iconSize),
              child: DefaultTextStyle(
                style: TextStyle(color: color, fontSize: widget.iconSize),
                child: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
