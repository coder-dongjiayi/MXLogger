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
    "color":MXTheme.white
  },
  {
    "level":"DEBUG",
    "color":MXTheme.debug,
  },
  {
    "level":"INFO",
    "color":MXTheme.info,
  },
  {
    "level":"WAENING",
    "color":MXTheme.warn,
  },
  {
    "level":"ERROR",
    "color":MXTheme.error,
  },
  {
    "level":"FATAL",
    "color":MXTheme.fatal,
  }
];