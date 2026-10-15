import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/settings_store.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_repository.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';

/// 可导入的日志扩展名：只有 MXLogger 写出的 `.mx` 二进制日志（与桌面端文件选择器一致）
const String mxImportableExtension = ".mx";

/// 导入任务（数据页 loading / 失败 toast 消费）。
class ImportStore extends MXState<ImportState> {
  ImportStore(this._store) : super(const ImportState());

  final MXStore _store;

  List<String> _lastPaths = [];

  bool get canReparse => _lastPaths.isNotEmpty;

  /// 导入一批日志文件：读取 → isolate 解密/解析 → 分批入库，全程回报真实进度。
  /// [clearExisting] 为 true 时清空旧数据（替换），否则与已有数据合并（按
  /// timestamp 去重）。重新解析（改 Key/IV 重解当前文件）恒为替换。
  /// 解析失败不动库（改 Key/IV 重解析失败保留旧数据）。
  Future<void> importFiles(
    List<String> paths, {
    bool reparse = false,
    bool clearExisting = true,
  }) async {
    if (paths.isEmpty || value.isRunning) return;
    final CryptSettings crypt = _store.crypt.value;
    final HomeRepository repository = _store.repository;

    value = ImportState(status: ImportStatus.running, reparse: reparse);

    try {
      await repository.importFiles(
        paths: paths,
        cryptPairs: crypt.cryptPairs,
        clearExisting: reparse || clearExisting,
        onProgress: (progress) {
          if (value.step == progress.step &&
              value.percent == progress.percent &&
              value.fileLabel == progress.fileLabel) {
            return;
          }
          value = value.copyWith(
            step: progress.step,
            percent: progress.percent,
            fileLabel: progress.fileLabel,
          );
        },
      );
    } on ImportFailure catch (failure) {
      _fail(failure.error);
      return;
    } catch (_) {
      _fail(ImportError.readFailed);
      return;
    }

    _lastPaths = paths;
    value = value.copyWith(step: ImportStep.done, percent: 100);
    // 让 100% 的完成态可被感知
    await Future<void>.delayed(const Duration(milliseconds: 250));
    value = value.copyWith(status: ImportStatus.success);
    _refreshData();
  }

  /// 「应用并重新解析」：用新 Key/IV 重解析上一批文件
  Future<void> reparse() => importFiles(_lastPaths, reparse: true);

  /// 嵌入模式「刷新」：扫描日志目录并**清空重解析**（每次刷新都是全新一份数据，
  /// 不与上次结果合并，避免历史残留与去重带来的歧义）。
  /// 返回 false 表示目录不存在或没有可解析的文件，调用方据此提示用户。
  Future<bool> importFromDirectory(String directory) async {
    final List<String> paths = await _store.repository.listLogFiles(directory);
    if (paths.isEmpty) return false;
    await importFiles(paths, clearExisting: true);
    return true;
  }

  /// 清空全部数据并复位导入状态（调用方随后切回首次引导页）
  Future<void> clearAll() async {
    if (value.isRunning) return;
    await _store.repository.clearAll();
    _lastPaths = [];
    _store.wizardPaths.value = const <String>[];
    value = const ImportState();
    _refreshData();
  }

  /// 结果提示消费完毕后复位
  void reset() {
    value = const ImportState();
  }

  void _fail(ImportError error) {
    value = value.copyWith(status: ImportStatus.failure, error: error);
  }

  /// 数据集变了：复位视图状态并重查全部统计/列表。
  /// 单条折叠翻转随旧数据作废，但默认折叠态（allCollapsed）保留——
  /// 那是用户/端上的偏好，刷新日志不该把手机端默认折叠改回展开。
  void _refreshData() {
    _store.filter.value = const LogFilterState();
    _store.foldToggled.value = const <int>{};
    _store.copiedId.value = null;
    _store.logList.refresh();
    _store.levelCounts.refresh();
    _store.headerInfo.refresh();
    _store.tagOptions.refresh();
    _store.nameOptions.refresh();
  }
}
