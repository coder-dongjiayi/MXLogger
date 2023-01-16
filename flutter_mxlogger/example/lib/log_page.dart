import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

import 'package:path_provider/path_provider.dart';
class LogPage extends StatefulWidget {
  const LogPage({Key? key}) : super(key: key);

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late MXLogger _mxLogger;
  int _size = 0;
  final String _cryptKey = "abchjilokiuihjng";
  final String _iv = "abchjilokiuihqqq";
  String? loggerKey;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  Future<void> init() async {

    Directory directory = await  getApplicationDocumentsDirectory();
    _mxLogger = await MXLogger.initialize(
        nameSpace: "flutter.mxlogger",
        directory: directory.path,
        storagePolicy: MXStoragePolicyType.yyyy_MM_dd_HH,
        fileHeader: "这是ios flutter header",
        cryptKey: _cryptKey,
        iv: _iv);

    _mxLogger.setMaxDiskAge(60*60*24*7);
    _mxLogger.setMaxDiskSize(1024*1024*10);
    _mxLogger.setConsoleEnable(false);
    _mxLogger.setFileLevel(0);
    updateSize();

    print("path:${_mxLogger.diskcachePath}");
    print("loggerKey:${_mxLogger.loggerKey}");

    loggerKey = _mxLogger.getLoggerKey();

  }

  @override
  void dispose() {
    // TODO: implement dispose

    MXLogger.destroyWithLoggerKey(loggerKey!);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String mb = (_size / 1024 / 1024).toStringAsFixed(2);

    return Scaffold(

        appBar: AppBar(title: Text("mxlogger")),
        body: Center(
          child: Column(
            children: [
              Text("当前日志大小:${mb}MB"),
              ElevatedButton(
                onPressed: (){
                  _mxLogger.getLogFiles().forEach((element) {
                    print("${element.toString()}");
                  });
                },
                child: Text("获取日志文件"),
              ),

              ElevatedButton(
                  onPressed: () {

                    _mxLogger.info("这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据这是info数据", name: "mxlogger", tag: "network");
                    _mxLogger.warn("这是warn数据", name: "mxlogger", tag: "w");
                    _mxLogger.error("这是error数据", name: "mxlogger", tag: "e");
                    _mxLogger.fatal("这是fatal数据", name: "mxlogger", tag: "f");
                    updateSize();
                  },
                  child: Text("写入log")),
              ElevatedButton(
                onPressed: () {
                  int m1 = DateTime.now().millisecondsSinceEpoch;
                  for (int i = 0; i < 100000; i++) {
                    _mxLogger.info("This is mxlogger log",
                        name: "name", tag: "net");
                  }
                  int m2 = DateTime.now().millisecondsSinceEpoch;
                  print("时间:${m2 - m1}ms");
                  updateSize();
                },
                child: Text("写10万条数据"),
              ),
              ElevatedButton(
                onPressed: () {
                  _mxLogger.removeExpireData();
                  updateSize();
                },
                child: Text("清理过期日志"),
              ),
              ElevatedButton(
                onPressed: () {
                  MXLogger.logLoggerKey(loggerKey, 0, "这是map写入的数据 debug",tag: "loggerKey",name: "mxlogger_loggerKey");
                  MXLogger.logLoggerKey(loggerKey, 1, "这是map写入的数据 info",tag: "loggerKey",name: "mxlogger_loggerKey");
                  MXLogger.logLoggerKey(loggerKey, 2, "这是map写入的数据 warn",tag: "loggerKey",name: "mxlogger_loggerKey");
                  MXLogger.logLoggerKey(loggerKey, 3, "这是map写入的数据 error",tag: "loggerKey",name: "mxlogger_loggerKey");
                  MXLogger.logLoggerKey(loggerKey, 4, "这是map写入的数据 fatal",tag: "loggerKey",name: "mxlogger_loggerKey");
                },
                child: Text("mapKey写入日志"),
              ),
              ElevatedButton(
                onPressed: () {
                  _mxLogger.removeAll();
                  updateSize();
                },
                child: Text("删除所有日志文件"),
              )
            ],
          ),
        ));
  }

  void updateSize() {
    _size = _mxLogger.logSize;
    setState(() {});
  }
}
