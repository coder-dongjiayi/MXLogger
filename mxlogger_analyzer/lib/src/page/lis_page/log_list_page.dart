import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/mxlogger_detail_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';

import 'package:provider/provider.dart';

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
      body: ChangeNotifierProvider(create: (context){
        return LogController();
      },builder: (context,child){
        return AsyncFutureLoader(asyncBuilder: (){
          return context.read<LogController>().loadData();
        }, successWidgetBuilder: (BuildContext context,List<LogModel>? list){
          return LogListView(
            dataSource: list!,
            callback: (index){
              Navigator.of(context).push(MaterialPageRoute(builder: (context){
                return MXLoggerDetailPage(logModel: list[index]);
              }));
            },
          );
        });
      },),
    );
  }
}
