import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

class ChangeLogScreen extends ConsumerWidget {
  const ChangeLogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
        backgroundColor: MXTheme.themeColor,
      //   appBar: AppBar(
      //     title: Text("更新日志"),
      //     backgroundColor: Colors.transparent,
      //     elevation: 0,
      //   ),
      // body: ListView(
      //   children: [
      //
      //   ],
      // ),
    );
  }


}
