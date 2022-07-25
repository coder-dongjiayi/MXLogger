import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/page/log_model.dart';
import 'package:mxlogger_analyzer/src/widget/log_listview.dart';

import '../theme/mx_theme.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {

  List<LogModel> _dataSource = [];
  @override
  void initState() {
   super.initState();

   LogModel model = LogModel(name: "name",tag: "net",msg: "this is message", level: 0, timestamp: 123456);
   _dataSource.add(model);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      body: LogListView(
        dataSource: _dataSource,
      ),
    );
  }
}
