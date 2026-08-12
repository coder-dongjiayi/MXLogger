enum ImportStatus { idle, running, success, failure }

/// 加载步骤（对齐设计稿 setLoad 的阶段文案）。
enum ImportStep { reading, decrypting, indexing, done }

/// [noRecords]：文件都能正常解析但没有一条日志记录（如刚初始化、还没写过
/// 日志的空 .mx），与 Key/IV 错误（[parseFailed]）区分提示。
enum ImportError { parseFailed, readFailed, noRecords }

/// 导入任务状态机：idle → running(步骤 + 真实百分比) → success/failure。
class ImportState {
  const ImportState({
    this.status = ImportStatus.idle,
    this.step = ImportStep.reading,
    this.percent = 0,
    this.fileLabel = "",
    this.error,
    this.reparse = false,
  });

  final ImportStatus status;
  final ImportStep step;

  /// 0-100，来自解析字节偏移 / 入库条数的真实进度
  final int percent;

  /// 加载页展示的文件名（含大小）
  final String fileLabel;
  final ImportError? error;

  /// 本次是否为「应用并重新解析」触发（决定完成后的 toast 文案）
  final bool reparse;

  bool get isRunning => status == ImportStatus.running;

  ImportState copyWith({
    ImportStatus? status,
    ImportStep? step,
    int? percent,
    String? fileLabel,
    ImportError? error,
    bool? reparse,
  }) {
    return ImportState(
      status: status ?? this.status,
      step: step ?? this.step,
      percent: percent ?? this.percent,
      fileLabel: fileLabel ?? this.fileLabel,
      error: error ?? this.error,
      reparse: reparse ?? this.reparse,
    );
  }
}
