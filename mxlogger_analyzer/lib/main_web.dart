/// 普通浏览器入口：复用 Chrome 扩展的 Web 宿主与分析器 UI。
///
/// 在 mxlogger_analyzer 目录先运行 `bash ../scripts/prepare_web.sh`
/// 生成解析 Worker 和浏览器资源，
/// 再运行 `flutter run -d chrome -t lib/main_web.dart`。
/// 发布构建使用 `bash ../scripts/build_web.sh`。
library;

import 'package:mxlogger_chrome_prototype/main.dart' as browser;

void main() => browser.main();
