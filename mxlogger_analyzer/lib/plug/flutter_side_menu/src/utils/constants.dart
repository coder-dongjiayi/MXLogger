import 'package:flutter/material.dart';

class Constants {
  /// Size
  static const double minWidth = 50.0;
  static const double maxWidth = 250.0;
  static const double zeroWidth = 0.0;
  static const double itemHeight = 40.0;
  static const double itemSelectedLineHeight = 20.0;
  static const double itemSelectedLineWidth = 4.0;

  /// Durations
  static const Duration duration = Duration(milliseconds: 200);

  /// Colors
  static const Color selectedColor = Color(0xff0055c3);
  static const Color highlightSelectedColor = Color(0xffe6effb);
  static const Color hoverColor = Colors.transparent;
  static const Color unSelectedColor = Color(0xff8e8e8e);
  static const Color backgroundColor = Color(0xffffffff);

  /// Padding
  static const EdgeInsetsDirectional textStartPadding =
      EdgeInsetsDirectional.only(
    start: 16,
  );
  static const EdgeInsetsDirectional zeroPadding = EdgeInsetsDirectional.zero;

  /// Margin
  static const EdgeInsetsDirectional itemMargin = EdgeInsetsDirectional.only(
    start: 4,
    end: 4,
    top: 4,
  );

  ///Space
  static const double badgeSpaceFromEnd = 12.0;

  /// BorderRadius
  static const BorderRadius radius_4 = BorderRadius.all(
    Radius.circular(4),
  );
}
