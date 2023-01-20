import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/page/debug_page/debug_page.dart';
class MXDebugPage extends StatelessWidget {
  const MXDebugPage(
      {Key? key,
        required this.diskcachePath,
        required this.databasePath,
        this.child,
        this.cryptKey,
        this.iv})
      : super(key: key);

  final String diskcachePath;
  final String databasePath;
  final String? cryptKey;
  final String? iv;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
        child: DebugPage(
          diskcachePath: diskcachePath,
          databasePath: databasePath,
          cryptKey: cryptKey,
          iv: iv,
        ));
  }
}

