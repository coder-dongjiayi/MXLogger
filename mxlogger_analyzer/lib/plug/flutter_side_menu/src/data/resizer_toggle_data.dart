import 'package:flutter/material.dart';

class ResizerToggleData {
  const ResizerToggleData({
    this.iconColor = Colors.black,
    this.topPosition = 20,
    this.opacity = 0.3,
    this.iconSize = 20,
  })  : assert(topPosition >= 0.0),
        assert(opacity >= 0.0),
        assert(iconSize >= 0.0);

  final Color iconColor;
  final double topPosition, opacity, iconSize;
}
