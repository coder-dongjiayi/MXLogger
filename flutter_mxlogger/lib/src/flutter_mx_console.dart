
import 'dart:developer' as developer;

class ConsoleLog {
  String pattern;
  int level = 0;
  ConsoleLog({this.pattern = "[%d][%p]%m"});

  void log(int level,  String msg, {String? name,  String? tag}) {
    if(level < this.level) return;

    String levelString = "DEBUG";
    switch(level){
      case 0:
        levelString = "DEBUG";
        break;
      case 1:
        levelString ="INFO";
        break;
      case 2:
        levelString = "WARN";
        break;
      case 3:
        levelString = "ERROR";
        break;
      case 4:
        levelString ="FATAL";
        break;
      default:
        levelString = "DEBUG";
        break;
    }

    String _logMessage =
        pattern.replaceAll("%", "").replaceAllMapped(RegExp(r"(\w+)"), (match) {
      switch (match.group(0)) {
        case "d":
          return DateTime.now().toString();
        case "p":
          return levelString;
        case "m":
          return msg;
      }
      return "";
    });
   developer.log(_logMessage,name: name ?? "mxlogger");
  }
}
