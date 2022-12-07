import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_riverpod.dart';

import 'package:mxlogger_analyzer/src/page/lis_page/view/crypt_dialog.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';
import 'package:tuple/tuple.dart';
import '../../analyzer_data/analyzer_binary.dart';
import '../../storage/mxlogger_storage.dart';
import '../../theme/mx_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../detail_page/mxlogger_detail_page.dart';
import 'package:mxlogger_analyzer/src/extends/async_extends.dart';
class LogListPage extends ConsumerStatefulWidget {
  const LogListPage({Key? key}) : super(key: key);

  @override
  LogListPageState createState() => LogListPageState();
}

class LogListPageState extends ConsumerState<LogListPage>
    with AutomaticKeepAliveClientMixin {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();


  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: const LogAppBar(),
      body: DropTarget(onDragEntered: (detail) {
        // mxLoggerController.dropTargetAction(true);
      }, onDragExited: (detail) {
        // mxLoggerController.dropTargetAction(false);
      }, onDragDone: (detail) async {
        if (MXLoggerStorage.instance.cryptAlert != true) {
          bool? result = await CryptDialog.show(context);
          // mxLoggerController.dropTargetAction(false);
          if (result != true) return;
        }
        XFile file = detail.files.first;
        ref.read(updateBinaryXFileProvider.notifier).state = file;
        //
        // AnalyzerBinary.loadData(
        //     file: file,
        //     cryptKey: MXLoggerStorage.instance.cryptKey,
        //     iv: MXLoggerStorage.instance.cryptIv,
        //     onStartCallback: () {
        //       EasyLoading.show(status: "正在导入数据");
        //     },
        //     onProgressCallback: (int total, int current) {
        //       double progress = current / total;
        //       EasyLoading.showProgress(progress,
        //           status: "正在解析数据:${progress.truncate()}");
        //     },
        //     onEndCallback: (success, field) {
        //       if (field == 0) {
        //         EasyLoading.showSuccess("共$success条数据导入成功");
        //       } else {
        //         EasyLoading.showToast("${success}条数据导入成功，$field条数据导入失败",
        //             duration: Duration(seconds: 5));
        //       }
        //
        //       // requestController.asyncController.refresh();
        //     });
      }, child: Consumer(builder: (context, ref, _) {
        var config = ref.watch(logPagesProvider);

        return config.when(
            data: (list) {
              return LogListView(
                dataSource: list,
                callback: (index) {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return MXLoggerDetailPage(logModel: list[index]);
                  }));
                },
              );
            },
            error: (Object error, StackTrace stackTrace) {
              return const SizedBox();
            },
            loading: () => const SizedBox());
      })),
      // child: AsyncFutureLoader(
      //     asyncController: requestController.asyncController,
      //     asyncBuilder: () {
      //       return requestController.refresh();
      //     },
      //     emptyWidgetBuilder: (BuildContext context, bool? result) {
      //       if (requestController.dataSource.isEmpty == true) {
      //         context
      //             .read<MXTextFieldController>()
      //             .focusNode
      //             .requestFocus();
      //         return requestController.search == false
      //             ? _empty()
      //             : Center(
      //             child: Text(
      //               "暂无搜索结果",
      //               style: TextStyle(color: MXTheme.subText),
      //             ));
      //       }
      //       return null;
      //     },
      //     successWidgetBuilder:
      //         (BuildContext context, bool? result) {
      //       final list =
      //           context.watch<RequestController>().dataSource;
      //       context
      //           .read<MXTextFieldController>()
      //           .focusNode
      //           .requestFocus();
      //       return LogListView(
      //         dataSource: list,
      //         callback: (index) {
      //           Navigator.of(context)
      //               .push(MaterialPageRoute(builder: (context) {
      //             return MXLoggerDetailPage(
      //                 logModel:
      //                 requestController.dataSource[index]);
      //           }));
      //         },
      //       );
      //     })),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.file_copy_sharp,
            size: 40,
            color: MXTheme.buttonColor,
          ),
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
