import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

import 'package:mxlogger_analyzer/src/host/desktop_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 桌面壳注入平台能力（shared_preferences / file_picker / desktop_drop），
  // 内核自身不依赖这些插件
  final MXHost host = await createDesktopHost();
  runApp(MXScope(
    store: MXStore(host: host),
    child: const MXLoggerAnalyzerApp(),
  ));
}
