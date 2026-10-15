import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/global/host/mx_host.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';

/// 优先通过宿主打开链接，宿主不可用或打开失败时复制地址。
Future<void> mxOpenExternalLink(BuildContext context, Uri uri) async {
  final MXOpenExternalLink? open = MXScope.of(context).host.openExternalLink;
  if (open != null) {
    try {
      if (await open(uri)) return;
    } catch (_) {}
  }
  try {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) showMXToast(context, context.l10n.openLinkCopied);
  } catch (_) {
    if (context.mounted) showMXToast(context, context.l10n.openLinkFailed);
  }
}
