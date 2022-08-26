import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/mxlogger_detail_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';

import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../analyzer_data/analyzer_binary.dart';
import '../../theme/mx_theme.dart';
import 'log_controller.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/view/async_future_loader.dart';
import 'package:easy_refresh/easy_refresh.dart';
class LogListPage extends StatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
   FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
   
    return ChangeNotifierProvider(
      create: (context) {
        return LogController();
      },
      builder: (context, child) {
        LogController logController =   context.read<LogController>();

        return KeyboardListener(onKeyEvent: (event){
          if(event.physicalKey.usbHidUsage == 0x00070028){
            logController.entry();
          }
        }, focusNode: _focusNode, child: Scaffold(
          backgroundColor: MXTheme.themeColor,
          appBar: const LogAppBar(),
          body: EasyRefresh(
            onLoad: () async{
              await Future.delayed(const Duration(seconds: 1));
              await logController.loadMore();
            },
            footer: ClassicFooter(
                textStyle: TextStyle(color: MXTheme.white),
                messageStyle: TextStyle(color: MXTheme.white),
                iconTheme: IconThemeData(color: MXTheme.white)
            ),

            child: DropTarget(
                onDragDone: (detail) async {
                  XFile file = detail.files.first;
                  Uint8List? data = await file.readAsBytes();
                  await AnalyzerBinary.loadData(binaryData: data);
                  logController.asyncController.refresh();
                },
                child: AsyncFutureLoader(asyncController: logController.asyncController, asyncBuilder: () {
                  return logController.refresh();
                }, emptyWidgetBuilder:
                    (BuildContext context,  bool? result) {
                  if (logController.dataSource.isEmpty == true) {
                    String emptyString = logController.keyWord == null ?  "拖拽日志文件到窗口" : "暂无搜索结果";

                    return  Center(child: Text(emptyString,style: TextStyle(color: MXTheme.white),));
                  }
                  return null;
                }, successWidgetBuilder:
                    (BuildContext context, bool? result) {
                  final list =    context.watch<LogController>().dataSource;
                  return LogListView(
                    dataSource: list,
                    callback: (index) {
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (context) {
                        return MXLoggerDetailPage(logModel: logController.dataSource[index]);
                      }));
                    },
                  );
                })),
          ),
        ));
      },
    );
  }
}
