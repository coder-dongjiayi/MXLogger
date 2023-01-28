import 'package:flutter/material.dart';
import '../data/resizer_toggle_data.dart';
import '../utils/utils.dart';

class ResizerToggle extends StatefulWidget {
  const ResizerToggle({
    Key? key,
    required this.onTap,
    required this.rightArrow,
    this.leftPosition = true,
    ResizerToggleData? data,
  })  : data = data ?? const ResizerToggleData(),
        super(key: key);
  final void Function() onTap;
  final bool rightArrow, leftPosition;
  final ResizerToggleData data;

  @override
  State<ResizerToggle> createState() => _ResizerToggleState();
}

class _ResizerToggleState extends State<ResizerToggle> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: widget.data.topPosition,
      child: InkWell(
        onTap: () => widget.onTap(),
        onHover: (hover) {
          setState(() {
            _visible = hover;
          });
        },
        child: AnimatedOpacity(
          opacity: _visible ? 1 : widget.data.opacity,
          duration: Duration.zero,
          child: RotatedBox(
            quarterTurns: widget.leftPosition
                ? widget.rightArrow
                    ? 12
                    : 6
                : widget.rightArrow
                    ? 6
                    : 12,
            child: Card(
              margin: EdgeInsets.zero,
              child: Icon(
                Utils.isRTL(context)
                    ? Icons.keyboard_arrow_left_outlined
                    : Icons.keyboard_arrow_right_outlined,
                color: widget.data.iconColor,
                size: widget.data.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
