import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

/// 系统分享（对齐设计稿 shareContent）：优先系统分享面板，
/// 携带 [fileName] 时以文本文件分享；不可用/失败时降级复制到剪贴板。
Future<void> mxShare(
  BuildContext context, {
  required String title,
  required String text,
  String? fileName,
}) async {
  final Rect origin = _shareOrigin(context);
  try {
    final ShareResult result;
    if (fileName != null) {
      result = await SharePlus.instance.share(ShareParams(
        title: title,
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(text)),
            name: fileName,
            mimeType: "text/plain",
          ),
        ],
        fileNameOverrides: [fileName],
        sharePositionOrigin: origin,
      ));
    } else {
      result = await SharePlus.instance.share(ShareParams(
        title: title,
        text: text,
        sharePositionOrigin: origin,
      ));
    }
    if (result.status != ShareResultStatus.unavailable) return;
  } catch (_) {}

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
