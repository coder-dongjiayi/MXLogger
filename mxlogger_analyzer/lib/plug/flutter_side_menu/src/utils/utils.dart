import 'package:flutter/material.dart';

class Utils {
  static bool isRTL(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl;
}
