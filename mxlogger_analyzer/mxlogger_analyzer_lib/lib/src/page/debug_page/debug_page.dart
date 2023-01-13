import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
class DebugPage extends ConsumerStatefulWidget {
   DebugPage ({Key? key,required this.diskcachePath,this.cryptKey,this.iv}) : super(key: key);
  final String diskcachePath;
  final String? cryptKey;
  final String? iv;
  @override
  DebugPageState createState() => DebugPageState();
}

class DebugPageState extends ConsumerState<DebugPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      body: LogListPage(),
    );
  }
}
