import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_provider.dart';

import 'package:mxlogger_analyzer/src/page/lis_page/view/crypt_dialog.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_app_bar.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/log_listview.dart';

import '../../controller/mxlogger_repository.dart';
import '../../storage/mxlogger_storage.dart';
import '../../theme/mx_theme.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../detail_page/mxlogger_detail_page.dart';


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
    super.build(context);
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: const LogAppBar(),
      body: DropTarget(onDragEntered: (detail) {

        ref.read(dropTargetProvider.notifier).state = true;
      }, onDragExited: (detail) {
        ref.read(dropTargetProvider.notifier).state = false;
      }, onDragDone: (detail) async {
        if (MXLoggerStorage.instance.cryptAlert != true) {
          bool? result = await CryptDialog.show(context);
          ref.read(dropTargetProvider.notifier).state = false;
          if (result != true) return;
        }
        XFile file = detail.files.first;
        ref.read(mxloggerRepository).importBinaryData(
            file: file,
            cryptKey: MXLoggerStorage.instance.cryptKey,
            cryptIv: MXLoggerStorage.instance.cryptIv).listen((event) {
              int status = event["status"];
              String message = event["message"] ?? "";
              switch (status) {
                case 0:
                  EasyLoading.show(status: message);
                  break;
                case 1:
                  double progress = event["progress"];
                  EasyLoading.showProgress(progress,status: message);
                  break;
                case 2:
                  EasyLoading.showSuccess(message);
                  break;
                case 3:
                  EasyLoading.showInfo(message);
                 break;
              }
              /// 刷新数据
              ref.invalidate(logPagesProvider);
        });

      }, child: Consumer(builder: (context, ref, _) {
        var config = ref.watch(logPagesProvider);
        return config.when(
            data: (list) {
              if(list.isEmpty){
                return _empty();
              }
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
            loading: () =>  Center(child: CupertinoActivityIndicator(color: MXTheme.white,)));
      })),
    );
  }

  Widget _empty() {
   bool  dataEmpty =  ref.read(emptyLogProvider);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            dataEmpty != true ? Icons.hourglass_empty : Icons.file_copy_sharp,
            size: 40,
            color: MXTheme.buttonColor,
          ),
          const SizedBox(height: 15),
          Text(
            dataEmpty != true ? "没有搜索到任何数据" :"拖拽日志文件到窗口",
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
