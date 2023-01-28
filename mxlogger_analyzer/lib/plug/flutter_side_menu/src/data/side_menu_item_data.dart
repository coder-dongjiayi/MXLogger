import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

abstract class SideMenuItemData {
  const SideMenuItemData();
}

class SideMenuItemDataTile extends SideMenuItemData {
  const SideMenuItemDataTile({
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.title,
    this.titleStyle,
    this.tooltip,
    this.badgeContent,
    this.hasSelectedLine = true,
    this.selectedLineSize = const Size(
      Constants.itemSelectedLineWidth,
      Constants.itemSelectedLineHeight,
    ),
    this.itemHeight = Constants.itemHeight,
    this.margin = Constants.itemMargin,
    this.borderRadius = Constants.radius_4,
    this.selectedColor = Constants.selectedColor,
    this.unSelectedColor = Constants.unSelectedColor,
    this.highlightSelectedColor = Constants.highlightSelectedColor,
    this.hoverColor = Constants.hoverColor,
    this.badgeColor = Constants.selectedColor,
    this.badgePosition = const BadgePosition(
      end: Constants.badgeSpaceFromEnd,
    ),
  })  : assert(itemHeight >= 0.0),
        assert(icon != null || title != null),
        super();

  final bool isSelected, hasSelectedLine;
  final void Function() onTap;
  final Size selectedLineSize;
  final String? title;
  final TextStyle? titleStyle;
  final String? tooltip;
  final Widget? badgeContent;
  final BadgePosition badgePosition;
  final Widget? icon;
  final double itemHeight;
  final EdgeInsetsDirectional margin;
  final BorderRadius borderRadius;
  final Color selectedColor,
      unSelectedColor,
      highlightSelectedColor,
      hoverColor,
      badgeColor;
}

class SideMenuItemDataTitle extends SideMenuItemData {
  const SideMenuItemDataTitle({
    required this.title,
    this.titleStyle,
    this.padding = Constants.itemMargin,
  }) : super();

  final String title;
  final TextStyle? titleStyle;
  final EdgeInsetsDirectional padding;
}

class SideMenuItemDataDivider extends SideMenuItemData {
  const SideMenuItemDataDivider({
    required this.divider,
    this.padding = Constants.itemMargin,
  }) : super();

  final Divider divider;
  final EdgeInsetsDirectional padding;
}
