import 'package:path_provider/path_provider.dart';

import 'package:mxlogger_analyzer_lib/src/data/database/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/locale_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/screen_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/theme_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/store/import_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/store/log_list_store.dart';

/// 分析器全部状态的持有者，由宿主创建后经 MXScope 注入组件树：
/// ```dart
/// final MXStore store = MXStore(host: desktopHost);
/// runApp(MXScope(store: store, child: const MXLoggerAnalyzerApp()));
/// ```
/// [host] 承载平台能力（设置落盘 / 选文件 / 拖入文件），不传即全部走
/// 默认实现（设置仅存内存、无选文件与拖入），嵌入模式即用这套默认值。
/// 测试可直接注入 [repository] / [database] 隔离数据层。
class MXStore {
  MXStore({
    MXHost? host,
    String? databasePath,
    AnalyzerDatabase? database,
    HomeRepository? repository,
    this.diskcachePath,
  })  : host = host ?? MXHost(),
        _ownsDatabase = database == null {
    this.database = MXAsyncState<AnalyzerDatabase>(() async {
      if (database != null) return database;
      final String path =
          databasePath ?? (await getApplicationSupportDirectory()).path;
      final AnalyzerDatabase opened = AnalyzerDatabase(path);
      opened.open();
      return opened;
    });
    this.repository = repository ?? HomeRepository(() => this.database.future);

    final MXPrefs prefs = this.host.prefs;
    themeMode = ThemeModeStore(prefs);
    locale = LocaleStore(prefs);
    crypt = CryptSettingsStore(prefs);
    screen = ScreenStore(prefs);

    filter = MXState<LogFilterState>(const LogFilterState());
    foldToggled = MXState<Set<int>>(const <int>{});
    allCollapsed = MXState<bool>(false);
    copiedId = MXState<int?>(null);
    timeOpen = MXState<bool>(false);
    headerCollapsed = MXState<bool>(false);
    wizardPaths = MXState<List<String>>(const <String>[]);

    levelCounts = MXAsyncState<Map<int, int>>(() => this.repository.fetchLevelCounts());
    headerInfo = MXAsyncState<HeaderInfo>(() => this.repository.fetchHeaderInfo());
    tagOptions = MXAsyncState<List<String>>(() => this.repository.fetchTagOptions());
    nameOptions = MXAsyncState<List<String>>(() => this.repository.fetchNameOptions());

    logList = LogListStore(this);
    importer = ImportStore(this);
  }

  /// 平台能力（设置落盘 / 选文件 / 拖入文件），未注入的能力走默认实现
  final MXHost host;

  /// 嵌入模式（[MXAnalyzer]）宿主 app 的日志目录；桌面壳为 null。
  /// 非空即代表「日志来源固定为本机目录」：数据源不靠拖入/选择文件，
  /// 而是由用户点「刷新」触发扫描解析（见 `ImportStore.importFromDirectory`）。
  final String? diskcachePath;

  /// 嵌入宿主 app 内运行（悬浮球 + 弹窗），而非独立桌面壳
  bool get isEmbedded => diskcachePath != null;

  /// 外部注入的数据库不由本 store 关闭
  final bool _ownsDatabase;

  /// 全局唯一数据库连接（首次被查询时打开，随 store 销毁关闭）
  late final MXAsyncState<AnalyzerDatabase> database;

  /// 日志数据层：解析、入库、查询、统计
  late final HomeRepository repository;

  late final ThemeModeStore themeMode;
  late final LocaleStore locale;
  late final CryptSettingsStore crypt;
  late final ScreenStore screen;

  /// 列表过滤条件
  late final MXState<LogFilterState> filter;

  /// 折叠态与默认相反的日志 id（翻转集）：
  /// 某条是否折叠 = [allCollapsed] 异或「id 在本集合里」。
  /// 用翻转集而非「折叠 id 集合」，未加载的分页也自动跟随默认态，无需逐条登记。
  late final MXState<Set<int>> foldToggled;

  /// 卡片默认折叠（「折叠全部」开关，手机端默认开）
  late final MXState<bool> allCollapsed;

  /// 复制成功的日志 id（1.2s 内按钮显示对勾）
  late final MXState<int?> copiedId;

  /// 时间范围面板展开态
  late final MXState<bool> timeOpen;

  /// 手机端筛选区（等级分布条+等级 chips+搜索/时间/折叠工具栏）收起态，
  /// 由左下角悬浮按钮切换，收起后整屏都留给日志
  late final MXState<bool> headerCollapsed;

  /// 首次向导已选择的日志文件路径
  late final MXState<List<String>> wizardPaths;

  /// 等级统计（分布条 + chips 计数）
  late final MXAsyncState<Map<int, int>> levelCounts;

  /// 数据页头部信息（总数/起止时间/文件名/文件头）
  late final MXAsyncState<HeaderInfo> headerInfo;

  /// 搜索联想候选：全部 tag / name
  late final MXAsyncState<List<String>> tagOptions;
  late final MXAsyncState<List<String>> nameOptions;

  late final LogListStore logList;
  late final ImportStore importer;

  void dispose() {
    for (final MXState<Object?> state in <MXState<Object?>>[
      themeMode,
      locale,
      crypt,
      screen,
      filter,
      foldToggled,
      allCollapsed,
      copiedId,
      timeOpen,
      headerCollapsed,
      wizardPaths,
      levelCounts,
      headerInfo,
      tagOptions,
      nameOptions,
      logList,
      importer,
    ]) {
      state.dispose();
    }
    // 未被使用过的连接不必打开一次再关
    if (_ownsDatabase && database.isStarted) {
      database.future.then((AnalyzerDatabase opened) => opened.dispose()).ignore();
    }
    database.dispose();
  }
}
