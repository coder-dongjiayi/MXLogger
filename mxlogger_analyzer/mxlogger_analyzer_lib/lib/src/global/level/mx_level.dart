/// 日志等级定义（值与 MXLogger native 端一致）。
const List<int> mxAllLevels = [0, 1, 2, 3, 4];

String mxLevelName(int level) {
  switch (level) {
    case 0:
      return "DEBUG";
    case 1:
      return "INFO";
    case 2:
      return "WARN";
    case 3:
      return "ERROR";
    case 4:
      return "FATAL";
    default:
      return "DEBUG";
  }
}
