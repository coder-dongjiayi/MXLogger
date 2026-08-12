/// MXLogger 2.0 日志分析器：既可作为独立桌面 app 的内核，
/// 也可通过 [MXAnalyzer] 以悬浮球+弹窗形式嵌入任意 Flutter app。
library;

/// 嵌入式调试入口（悬浮球 + 底部弹窗）
export 'package:mxlogger_analyzer_lib/src/embed/mx_analyzer.dart';

/// 独立 app 壳（桌面端入口使用）
export 'package:mxlogger_analyzer_lib/src/app/app.dart';
export 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 宿主能力适配层（设置存储 / 选文件 / 拖入文件），桌面壳注入平台实现
export 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
export 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';

/// 基于 stream 的轻量状态管理（MXState / MXAsyncState / MXScope / 消费组件）
export 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
export 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';

/// 宿主可按需触达的状态容器
export 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
export 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
export 'package:mxlogger_analyzer_lib/src/global/store/theme_store.dart';
export 'package:mxlogger_analyzer_lib/src/global/store/locale_store.dart';
export 'package:mxlogger_analyzer_lib/src/global/store/screen_store.dart';

/// 页面（自定义嵌入方式时可直接使用）
export 'package:mxlogger_analyzer_lib/src/screens/main/main_screen.dart';
export 'package:mxlogger_analyzer_lib/src/screens/home/home_screen.dart';

/// 数据层（导入/查询能力）
export 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
export 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
export 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
export 'package:mxlogger_analyzer_lib/src/screens/home/store/import_store.dart';
export 'package:mxlogger_analyzer_lib/src/screens/home/store/log_list_store.dart';
