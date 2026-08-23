import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

/// 分享（对齐设计稿 shareContent）：内核不依赖分享插件，
/// 优先走宿主经 [MXHost.share] 注入的实现（桌面壳注入 share_plus，
/// 嵌入模式由主 app 决定接入什么）；宿主未注入/不可用/失败时
/// 降级复制到剪贴板。携带 [fileName] 时期望以文本文件形式分享。
Future<void> mxShare(
  BuildContext context, {
  required String title,
  required String text,
  String? fileName,
}) async {
  final MXShareHandler? share = MXScope.of(context).host.share;
  if (share != null) {
    final MXShareRequest request = MXShareRequest(
      title: title,
      text: text,
      fileName: fileName,
      origin: _shareOrigin(context),
    );
    try {
      if (await share(request)) return;
    } catch (_) {}
  }

  try {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showMXToast(context, context.l10n.shareUnsupported);
  } catch (_) {
    if (context.mounted) showMXToast(context, context.l10n.shareFailed);
  }
}

/// macOS/iPad 的分享面板需要锚点，取触发控件的屏幕矩形
Rect _shareOrigin(BuildContext context) {
  final RenderObject? renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
  final Size size = MediaQuery.of(context).size;
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}
