import 'package:flutter/widgets.dart';

import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';

/// 选择日志文件：返回选中文件的绝对路径，取消选择返回空列表。
typedef MXPickLogFiles = Future<List<String>> Function();

/// 一次分享请求：内核把要分享的内容与锚点打包交给宿主。
class MXShareRequest {
  const MXShareRequest({
    required this.title,
    required this.text,
    this.fileName,
    required this.origin,
  });

  final String title;

  final String text;

  /// 非空表示希望以此文件名的文本文件形式分享（如导出日志），
  /// 为 null 则按纯文本分享
  final String? fileName;

  /// 分享面板锚点，即触发分享的控件的屏幕矩形（iPad/macOS 的
  /// popover 式分享面板需要）
  final Rect origin;
}

/// 分享能力：返回 true 表示宿主已处理（面板已弹出，用户取消也算）；
/// 返回 false 或抛错表示当前环境不可用，内核降级复制到剪贴板。
typedef MXShareHandler = Future<bool> Function(MXShareRequest request);

/// 把 [child] 包装成「拖入文件」目标：
/// 文件落下时以绝对路径列表回调 `onDrop`，指针进出目标时回调 `onDragOver`
/// （驱动虚线卡片的高亮）。
typedef MXDropTargetBuilder =
    Widget Function({
      required Widget child,
      required ValueChanged<List<String>> onDrop,
      required ValueChanged<bool> onDragOver,
    });

/// 宿主能力适配层：分析器内核不直接依赖任何平台插件，
/// 需要「落盘设置 / 选文件 / 拖入文件 / 分享」时都经这里由外部注入实现。
///
/// - 嵌入宿主 app（`MXAnalyzer`）：全部走默认值 —— 设置存内存、
///   不提供选文件与拖入（日志来源固定为宿主的日志目录，由用户点「刷新」
///   扫描解析）、分享降级为复制剪贴板；主 app 想用系统分享面板则自行接入
///   share_plus 等插件后经 [share] 注入。因此移动端集成分析器**不会**引入
///   shared_preferences / file_picker / desktop_drop / share_plus
///   这些宿主业务层可能已有或用不上的依赖。
/// - 桌面壳：注入基于上述插件的实现（见壳工程 `lib/src/host/desktop_host.dart`）。
class MXHost {
  MXHost({MXPrefs? prefs, this.pickLogFiles, this.dropTargetBuilder, this.share})
      : prefs = prefs ?? MXMemoryPrefs();

  /// 设置的本地存储，默认仅存内存
  final MXPrefs prefs;

  /// 选文件能力；null 表示宿主不提供（相关入口不展示、点了也不动作）
  final MXPickLogFiles? pickLogFiles;

  /// 拖入文件能力；null 表示宿主不提供（页面原样渲染，不套拖放目标）
  final MXDropTargetBuilder? dropTargetBuilder;

  /// 分享能力；null 表示宿主不提供，分享一律降级为复制到剪贴板
  final MXShareHandler? share;

  bool get canPickFiles => pickLogFiles != null;

  bool get canDropFiles => dropTargetBuilder != null;

  /// 按需把 [child] 套上拖放目标：宿主没提供拖入能力时原样返回，
  /// 调用方不必自己判空。
  Widget wrapDropTarget({
    required Widget child,
    required ValueChanged<List<String>> onDrop,
    required ValueChanged<bool> onDragOver,
  }) {
    final MXDropTargetBuilder? builder = dropTargetBuilder;
    if (builder == null) return child;
    return builder(child: child, onDrop: onDrop, onDragOver: onDragOver);
  }
}
