import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
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
        fileHeader: "version 1.2.5",
        cryptKey: _cryptKey,
        iv: _iv);

    _mxLogger.setMaxDiskAge(60*60*24*7);
    _mxLogger.setMaxDiskSize(1024*1024*10);
    _mxLogger.setConsoleEnable(true);
    _mxLogger.setFileLevel(0);
     updateSize();

    print("path:${_mxLogger.diskcachePath}");
    print("loggerKey:${_mxLogger.loggerKey}");

    loggerKey = _mxLogger.getLoggerKey();

  }

  void writeLog() async {

    _mxLogger.debug("这是条debug状态下的调试信息", tag: "login,service");

    _mxLogger.info("这是条Info状态下的调试信息", tag: "register");

    Map<String,dynamic> json1 = {
      "uri":"https://192.168.1.1/test",
      "method":"POST",
      "responseType":"ResponseType.json",
      "followRedirects":"true",
      "connectTimeout":"0",
      "receiveTimeout":"0",
      "extra":{},
      "Request headers":"{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data":"{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode":200,
      "Response Text":"{\"code\":0,\"msg\":\"操作成功\"}"
    };

    _mxLogger.info(jsonEncode(json1), tag: "network,POST,200");

    Map<String,dynamic> json2 = {
      "uri":"https://192.168.1.1/test",
      "method":"POST",
      "responseType":"ResponseType.json",
      "followRedirects":"true",
      "connectTimeout":"0",
      "receiveTimeout":"0",
      "extra":{},
      "Request headers":"{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data":"{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode":404,
      "Response Text":"{\"code\":0,\"msg\":\"操作成功\"}"
    };

    _mxLogger.warn(jsonEncode(json2), tag: "network,GET,404");

    String flutterError = """ 
The following _TypeError was thrown building LogPage(dirty, state: _LogPageState#0b85e):
type 'Null' is not a subtype of type 'String'

The relevant error-causing widget was: 
  LogPage LogPage:file:///xxxxxx/main2.dart:64:21
When the exception was thrown, this was the stack: 
#0      _LogPageState.build (package:example/log_page.dart:45:12)
#1      StatefulElement.build (package:flutter/src/widgets/framework.dart:4919:27)
#2      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:4806:15)
#3      StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:4977:11)
#4      Element.rebuild (package:flutter/src/widgets/framework.dart:4529:5)
#5      ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:4787:5)
#6      StatefulElement._firstBuild (package:flutter/src/widgets/framework.dart:4968:11)
#7      ComponentElement.mount (package:flutter/src/widgets/framework.dart:4781:5)
...     Normal element mounting (275 frames)
#282    Element.inflateWidget (package:flutter/src/widgets/framework.dart:3817:16)
#283    MultiChildRenderObjectElement.inflateWidget (package:flutter/src/widgets/framework.dart:6350:36)
#284    Element.updateChild (package:flutter/src/widgets/framework.dart:3551:18)
#285    RenderObjectElement.updateChildren (package:flutter/src/widgets/framework.dart:5883:32)
#286    MultiChildRenderObjectElement.update (package:flutter/src/widgets/framework.dart:6375:17)
#287    Element.updateChild (package:flutter/src/widgets/framework.dart:3530:15)
#288    ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:4832:16)
#289    StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:4977:11)
    """;
    _mxLogger.error(flutterError,tag: "flutter,crash");
    _mxLogger.fatal("这是条fatal状态下的调试信息", tag: "crash");
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
                    writeLog();
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
                  _mxLogger.removeBeforeAllData();
                  updateSize();
                },
                child: Text("清理除当前写入的所有日志文件"),
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
