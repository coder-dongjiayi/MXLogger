import 'package:auto_size_text/auto_size_text.dart';
import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import '../data/side_menu_item_data.dart';
import '../utils/constants.dart';

class SideMenuItemTile extends StatefulWidget {
  const SideMenuItemTile({
    Key? key,
    required this.isOpen,
    required this.minWidth,
    required this.data,
  }) : super(key: key);
  final SideMenuItemDataTile data;
  final bool isOpen;
  final double minWidth;

  @override
  State<SideMenuItemTile> createState() => _SideMenuItemTileState();
}

class _SideMenuItemTileState extends State<SideMenuItemTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.data.itemHeight,
      margin: widget.data.margin,
      decoration: BoxDecoration(
        color: _isHovering
            ? widget.data.hoverColor
            : widget.data.isSelected
                ? widget.data.highlightSelectedColor
                : null,
        borderRadius: widget.data.borderRadius,
      ),
      child: InkWell(
        onTap: widget.data.onTap,
        borderRadius: widget.data.borderRadius,
        child: _createView(context: context),
        onHover: (hover) {
          setState(() {
            _isHovering = hover;
          });
        },
      ),
    );
  }

  Widget _createView({
    required BuildContext context,
  }) {
    final content = _hasTooltip(
      child: _hasBadge(
        child: _content(
          context: context,
        ),
      ),
    );

    return widget.data.isSelected && widget.data.hasSelectedLine ? _hasSelectedLine(child: content) : content;
  }

  Widget _hasTooltip({
    required Widget child,
  }) {
    if (widget.data.tooltip != null) {
      return Tooltip(
        message: widget.data.tooltip,
        child: child,
      );
    }
    return child;
  }

  Widget _hasBadge({
    required Widget child,
  }) {
    if (widget.data.badgeContent != null) {
      return SizedBox();
    }
    return child;
  }

  Widget _content({
    required BuildContext context,
  }) {
    final hasIcon = widget.data.icon != null;
    final hasTitle = widget.data.title != null;
    if (hasIcon && hasTitle) {
      return Row(
        children: [
          _icon(),
          if (widget.isOpen)
            Expanded(
              child: _title(context: context),
            ),
        ],
      );
    } else if (hasIcon) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: _icon(),
      );
    } else {
      return Container(
        alignment: AlignmentDirectional.centerStart,
        padding: Constants.textStartPadding,
        child: _title(context: context),
      );
    }
  }

  Widget _icon() {
    return SizedBox(
      width: widget.minWidth - widget.data.margin.horizontal,
      height: double.maxFinite,
      child: widget.data.icon,
    );
  }

  Widget _title({
    required BuildContext context,
  }) {
    final TextStyle? titleStyle = widget.data.titleStyle ?? Theme.of(context).textTheme.bodyLarge;
    return AutoSizeText(
      widget.data.title!,
      style: titleStyle?.copyWith(
        color: widget.data.isSelected ? widget.data.selectedColor : widget.data.unSelectedColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _selectedLine() {
    return SizedBox.fromSize(
      size: widget.data.selectedLineSize,
      child: ColoredBox(
        color: widget.data.isSelected ? widget.data.selectedColor : widget.data.unSelectedColor,
      ),
    );
  }

  Widget _hasSelectedLine({
    required Widget child,
  }) {
    return Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        child,
        _selectedLine(),
      ],
    );
  }
}
