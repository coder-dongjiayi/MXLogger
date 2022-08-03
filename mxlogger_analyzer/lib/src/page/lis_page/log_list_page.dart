import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/mxlogger_detail_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';

import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../theme/mx_theme.dart';
import 'log_controller.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/view/async_future_loader.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      body: DropTarget(
        onDragDone: (detail){
          print(detail.files);

        },
          child: ChangeNotifierProvider(
        create: (context) {
          return LogController();
        },
        builder: (context, child) {
          return AsyncFutureLoader(asyncBuilder: () {
            return context.read<LogController>().loadData();
          }, emptyWidgetBuilder: (BuildContext context, List<LogModel>? list) {
            if (list?.isEmpty == true) {
              return const Center(child: Text("拖拽日志文件到窗口"));
            }
          }, successWidgetBuilder:
              (BuildContext context, List<LogModel>? list) {
            return LogListView(
              dataSource: list!,
              callback: (index) {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) {
                  return MXLoggerDetailPage(logModel: list[index]);
                }));
              },
            );
          });
        },
      )),
    );
  }
}
