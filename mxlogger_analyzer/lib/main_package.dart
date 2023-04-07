import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

GlobalKey<NavigatorState> _navigatorStateKey = GlobalKey<NavigatorState>();

class _MyAppState extends State<MyApp> {
  @override
  late MXLogger _mxLogger;

  final String _cryptKey = "abchjilokiuihjng";
  final String _iv = "abchjilokiuihqqq";

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String? _systemInfo;
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

      _systemInfo = json.encode(androidInfo.toMap());
    } else {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      _systemInfo = json.encode(iosInfo.toMap());
    }
    _mxLogger = await MXLogger.initialize(
        nameSpace: "flutter.mxlogger",
        storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
        fileHeader: _systemInfo,
        cryptKey: _cryptKey,
        iv: _iv);

    _mxLogger.setMaxDiskAge(60 * 60 * 24 * 7);
    _mxLogger.setMaxDiskSize(1024 * 1024 * 10);
    _mxLogger.setConsoleEnable(true);
    _mxLogger.setFileLevel(0);

    print("path:${_mxLogger.diskcachePath}");
    print("loggerKey:${_mxLogger.loggerKey}");
  }

  void writeLog() async {
    _mxLogger.debug("这是条debug状态下的调试信息", tag: "login,service");

    _mxLogger.debug("这是条debug状态下的调试信息", tag: "register");

    Map<String, dynamic> json1 = {
      "uri": "https://192.168.1.1/test",
      "method": "POST",
      "responseType": "ResponseType.json",
      "followRedirects": "true",
      "connectTimeout": "0",
      "receiveTimeout": "0",
      "extra": {"name": "张三"},
      "Request headers":
          "{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data": "{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode": 200,
      "Response Text": "{\"code\":0,\"msg\":\"操作成功\"}"
    };

    _mxLogger.info(jsonEncode(json1), tag: "network,POST,200");

    Map<String, dynamic> json2 = {
      "uri": "https://192.168.1.1/test",
      "method": "POST",
      "responseType": "ResponseType.json",
      "followRedirects": "true",
      "connectTimeout": "0",
      "receiveTimeout": "0",
      "extra": {},
      "Request headers":
          "{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data": "{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode": 404,
      "Response Text": "{\"code\":0,\"msg\":\"操作成功\"}"
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
    _mxLogger.error(flutterError, tag: "flutter,crash");
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorStateKey,
      home: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(child: Builder(
            builder: (context) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          writeLog();
                        },
                        child: Text("写入日志")),
                    Text("这是一行文本"),
                    ElevatedButton(
                        onPressed: () async {
                          Directory directory =
                              await getApplicationDocumentsDirectory();
                          MXAnalyzer.showDebug(
                              _navigatorStateKey.currentState!.overlay!,
                              diskcachePath: _mxLogger.diskcachePath,
                              cryptKey: _mxLogger.cryptKey,
                              iv: _mxLogger.iv,
                              databasePath: directory.path);
                        },
                        child: Text("显示调试器")),
                    ElevatedButton(
                      onPressed: () {
                        MXAnalyzer.dismiss();
                      },
                      child: Text("隐藏调试"),
                    ),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (context) {
                            return SecondPage();
                          }));
                        },
                        child: Text("进入二级页面"))
                  ],
                ),
              );
            },
          ))),
    );
  }
}

class SecondPage extends StatefulWidget {
  const SecondPage({Key? key}) : super(key: key);

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("second"),
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Text("这是push进来的页面"),
      ),
    );
  }
}
