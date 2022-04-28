import 'package:flutter/material.dart';


class MXTheme{
  static Color white =  Colors.white;
  static Color themeColor = const Color.fromRGBO(14, 34, 49, 1);
  static Color itemBackground = const Color.fromRGBO(34, 57, 75, 0.3);
  static Color text = const Color.fromRGBO(255, 255, 255, 0.5);
  static Color debug = const Color.fromRGBO(81, 143, 127, 1);
  static Color info = const Color.fromRGBO(113, 179, 196, 1);
  static Color warn = const Color.fromRGBO(233, 204, 123, 1);
  static Color error = const Color.fromRGBO(197, 73, 88, 1);
  static Color fatal = const Color.fromRGBO(226, 7, 35, 1);

  static Color colorLevel(int level){
    switch(level){
      case 0:
        return MXTheme.debug;
      case 1:
        return MXTheme.info;
      case 2:
        return MXTheme.warn;
      case 3:
        return MXTheme.error;
      case 4:
        return MXTheme.fatal;
      default:
        return MXTheme.white;
    }
  }
}



