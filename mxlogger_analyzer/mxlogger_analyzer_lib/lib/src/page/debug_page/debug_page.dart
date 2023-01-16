import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'dart:io';

class DebugPage extends ConsumerStatefulWidget {
  DebugPage({Key? key, required this.diskcachePath, this.cryptKey, this.iv})
      : super(key: key);
  final String diskcachePath;
  final String? cryptKey;
  final String? iv;
  @override
  DebugPageState createState() => DebugPageState();
}

class DebugPageState extends ConsumerState<DebugPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
   // Future.delayed(Duration(seconds: 5),(){
   //   _loadData();
   // });
  }

  void _loadData() {
    Directory directory = Directory(widget.diskcachePath);
    List<FileSystemEntity> fileList = directory.listSync();
    Uint8List bytes = File(fileList.first.path).readAsBytesSync();
    ref
        .read(mxloggerRepository)
        .importBytes(
            binaryData: bytes, cryptKey: widget.cryptKey, cryptIv: widget.iv)
        .listen((event) {
      int status = event["status"];
      String message = event["message"] ?? "";
      switch (status) {
        case 0:
          // EasyLoading.show(status: message);
          break;
        case 1:
          double progress = event["progress"];
          // EasyLoading.showProgress(progress, status: message);
          break;
        case 2:
          int repeat = event["repeat"];
          if (repeat > 0) {
            Future.delayed(Duration(seconds: 1), () {
              // EasyLoading.showInfo("${repeat}条数据已存在,请勿重复导入",
              //     duration: Duration(seconds: 3));
            });
          } else {
            print("数据导入完成");
            // EasyLoading.showSuccess(message);
          }
          // /// 刷新数据
          ref.invalidate(logPagesProvider);
          break;
        case 3:
          // EasyLoading.showInfo(message);
          ref.invalidate(logPagesProvider);
          break;
        case 4:
          ref.read(errorProvider).add(message);
          ref.read(errorListProvider.notifier).state =
              List.of(ref.read(errorProvider)).toList();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      body: Stack(
        alignment: Alignment.center,
        children: [
          LogListPage(),
          loading()
        ],
      ),
    );
  }
  Widget loading(){
    return Container(
      margin: EdgeInsets.only(bottom: 100),
      width: 200,
      height: 200,
      child: CupertinoActivityIndicator(
          radius:20,
        color: MXTheme.white,
      ),
    );
  }
}
