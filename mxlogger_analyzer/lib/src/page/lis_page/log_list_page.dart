import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
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
        return KeyboardListener(
            onKeyEvent: (event) {
              if (event.physicalKey.usbHidUsage == 0x00070028) {
                textFieldController.entry(context);
              }
            },
            focusNode: FocusNode(),
            child: Scaffold(
              backgroundColor: MXTheme.themeColor,
              appBar: const LogAppBar(),
              body: EasyRefresh(
                onLoad: () async {
                  await Future.delayed(const Duration(seconds: 1));
                  await requestController.loadMore();
                },
                header: ClassicHeader(
                    textStyle: TextStyle(color: MXTheme.white),
                    messageStyle: TextStyle(color: MXTheme.white),
                    iconTheme: IconThemeData(color: MXTheme.white)
                ),
                footer: ClassicFooter(
                    textStyle: TextStyle(color: MXTheme.white),
                    messageStyle: TextStyle(color: MXTheme.white),
                    iconTheme: IconThemeData(color: MXTheme.white)),
                child: DropTarget(
                    onDragDone: (detail) async {
                      await CryptDialog.show(context);

                      XFile file = detail.files.first;
                      Uint8List? data = await file.readAsBytes();
                      await AnalyzerBinary.loadData(
                          binaryData: data,
                          cryptKey: MXLoggerStorage.instance.cryptKey,
                          iv: MXLoggerStorage.instance.cryptIv);
                      requestController.asyncController.refresh();
                    },
                    child: AsyncFutureLoader(
                        asyncController: requestController.asyncController,
                        asyncBuilder: () {
                          return requestController.refresh();
                        },
                        emptyWidgetBuilder:
                            (BuildContext context, bool? result) {
                          if (requestController.dataSource.isEmpty == true) {
                            String emptyString = requestController.keyWord == null
                                ? "拖拽日志文件到窗口"
                                : "暂无搜索结果";

                            return Center(
                                child: Text(
                              emptyString,
                              style: TextStyle(color: MXTheme.white),
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
              ),
            ));
      },
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
