import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';


String levelName(int level){
  switch(level){
    case 0:
      return "DEBUG";
    case 1:
      return "INFO";
    case 2:
      return "WAENING";
    case 3:
      return "ERROR";
    case 4:
      return "FATAL";

  }
  return "DEBUG";
}

final List<Map<String,dynamic>> MXLevels = [
  {
    "level":"ALL",
    "color":MXTheme.white,
    "number":-1,
  },
  {
    "level":"DEBUG",
    "color":MXTheme.debug,
    "number":0,
  },
  {
    "level":"INFO",
    "color":MXTheme.info,
    "number":1,
  },
  {
    "level":"WAENING",
    "color":MXTheme.warn,
    "number":2,
  },
  {
    "level":"ERROR",
    "color":MXTheme.error,
    "number":3,
  },
  {
    "level":"FATAL",
    "color":MXTheme.fatal,
    "number":4,
  }
];