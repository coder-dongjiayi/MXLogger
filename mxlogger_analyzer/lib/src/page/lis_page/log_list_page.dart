import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_controller.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/mxlogger_detail_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/controller/request_controller.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_model.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/crypt_dialog.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';

import 'package:provider/provider.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../analyzer_data/analyzer_binary.dart';
import '../../storage/mxlogger_storage.dart';
import '../../theme/mx_theme.dart';
import 'controller/mx_textfield_controller.dart';
import 'package:mxlogger_analyzer/src/page/detail_page/view/async_future_loader.dart';
import 'package:easy_refresh/easy_refresh.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> with AutomaticKeepAliveClientMixin{

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return MultiProvider(
      providers: [

        ChangeNotifierProvider(create: (_){
          RequestController controller =    RequestController();
          context.read<MXLoggerController>().addRequestController(controller);
          return controller;
        }),
        ChangeNotifierProvider(create: (_) => MXTextFieldController())
      ],
      builder: (context, child) {
        RequestController requestController = context.read<RequestController>();
        MXTextFieldController textFieldController = context.read<MXTextFieldController>();
        MXLoggerController mxLoggerController = context.read<MXLoggerController>();

        return KeyboardListener(
            onKeyEvent: (event) {

              if (event.physicalKey.usbHidUsage == 0x00070028) {
                textFieldController.entry(context);
              }else if(event.physicalKey.usbHidUsage == 0x0007002b){
                textFieldController.focusNode.requestFocus();
              }
            },
            focusNode: FocusNode(),
            child: Scaffold(
              backgroundColor: MXTheme.themeColor,
              appBar: const LogAppBar(),
              body:  DropTarget(
                 onDragEntered: (detail){
                   mxLoggerController.dropTargetAction(true);
                 },
                onDragExited: (detail){
                  mxLoggerController.dropTargetAction(false);
                },
                  onDragDone: (detail) async {

                   if(MXLoggerStorage.instance.cryptAlert != true){
                     bool? result =   await CryptDialog.show(context);
                     mxLoggerController.dropTargetAction(false);
                     if(result != true) return;
                   }

                    XFile file = detail.files.first;

                     AnalyzerBinary.loadData(
                        file: file,
                        cryptKey: MXLoggerStorage.instance.cryptKey,
                        iv: MXLoggerStorage.instance.cryptIv,onStartCallback: (){
                          EasyLoading.show(status: "正在导入数据");
                     },onProgressCallback: (int total,int current){
                        double progress = current/total;
                        EasyLoading.showProgress(progress,status: "正在解析数据:${progress.truncate()}");
                     },onEndCallback: (number){
                       EasyLoading.showSuccess("共$number条数据导入成功");
                       requestController.asyncController.refresh();
                     });

                  },
                  child: AsyncFutureLoader(
                      asyncController: requestController.asyncController,
                      asyncBuilder: () {
                        return requestController.refresh();
                      },
                      emptyWidgetBuilder:
                          (BuildContext context, bool? result) {
                        if (requestController.dataSource.isEmpty == true) {
                          context.read<MXTextFieldController>().focusNode.requestFocus();
                          return requestController.search == false ? _empty() : Center(
                              child: Text(
                                "暂无搜索结果",
                                style: TextStyle(color: MXTheme.subText),
                              ));
                        }
                        return null;
                      },
                      successWidgetBuilder:
                          (BuildContext context, bool? result) {
                        final list =
                            context.watch<RequestController>().dataSource;
                        context.read<MXTextFieldController>().focusNode.requestFocus();
                        return LogListView(
                          dataSource: list,
                          callback: (index) {
                            Navigator.of(context)
                                .push(MaterialPageRoute(builder: (context) {
                              return MXLoggerDetailPage(
                                  logModel: requestController.dataSource[index]);
                            }));
                          },
                        );
                      })),
            ));
      },
    );
  }

  Widget _empty(){

    return  Center(
      child: Column(
        mainAxisAlignment:MainAxisAlignment.center,
        children: [
           Icon(Icons.file_copy_sharp,size: 40,color: MXTheme.buttonColor,),
          const SizedBox(height: 15),
          Text(
            "拖拽日志文件到窗口",
            style: TextStyle(color: MXTheme.subText),
          )
        ],
      ),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
