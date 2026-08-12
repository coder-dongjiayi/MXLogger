import 'package:flutter/material.dart';

/// 带 hover 反馈的点击区域。
///
/// 桌面端鼠标悬停时给出高亮，让可点的东西看起来可点——不然像"双击才能删"
/// 这类交互用户根本发现不了。
class MXHoverable extends StatefulWidget {
  const MXHoverable({Key? key, required this.builder, this.onTap})
      : super(key: key);

  final Widget Function(bool hovered) builder;

  /// 为 null 时只做悬停反馈，不接受点击
  final VoidCallback? onTap;

  @override
  State<MXHoverable> createState() => _MXHoverableState();
}

class _MXHoverableState extends State<MXHoverable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.builder(_hovered),
      ),
    );
  }
}
