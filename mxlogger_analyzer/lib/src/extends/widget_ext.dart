import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

extension WidgetEx on Widget? {
  Padding pOnly(
          {Key? key,
          double left = 0.0,
          double right = 0.0,
          double top = 0.0,
          double bottom = 0.0}) =>
      Padding(
        key: key,
        padding:
            EdgeInsets.only(left: left, right: right, top: top, bottom: bottom),
        child: this,
      );

  Container mOnly(
          {Key? key,
          double left = 0.0,
          double right = 0.0,
          double top = 0.0,
          double bottom = 0.0}) =>
      Container(
        key: key,
        margin:
            EdgeInsets.only(left: left, right: right, top: top, bottom: bottom),
        child: this,
      );

  Widget decorationEx({
    double? height,
    double? width,
    double radius = 2,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    alignment = Alignment.center,
    Color borderColor = Colors.transparent,
    Color bgColor = Colors.transparent,
  }) {
    return UnconstrainedBox(
      child: Container(
        width: width,
        height: height,
        padding: padding ?? EdgeInsets.symmetric(horizontal: 4),
        margin: margin,
        alignment: alignment,
        decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 0.5),
            borderRadius: BorderRadius.circular(radius) // 圆角度
            ),
        child: this,
      ),
    );
  }
}
