import 'package:flutter/material.dart';

class ResizerData {
  const ResizerData({
    this.resizerWidth = 3,
    this.iconColor = Colors.black,
    this.resizerColor = Colors.black12,
    this.resizerHoverColor = Colors.blue,
  }) : assert(resizerWidth >= 0.0);

  final double resizerWidth;
  final Color iconColor, resizerColor, resizerHoverColor;
}
