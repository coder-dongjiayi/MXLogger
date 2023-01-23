import 'dart:io';

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
    _mxLogger = await MXLogger.initialize(
        nameSpace: "flutter.mxlogger",
        storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
        fileHeader: "这是flutter header",
        cryptKey: _cryptKey,
        iv: _iv);

    _mxLogger.setMaxDiskAge(60 * 60 * 24 * 7);
    _mxLogger.setMaxDiskSize(1024 * 1024 * 10);
    _mxLogger.setConsoleEnable(true);
    _mxLogger.setFileLevel(0);

    print("path:${_mxLogger.diskcachePath}");
    print("loggerKey:${_mxLogger.loggerKey}");
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
                          _mxLogger.debug("这是debug信息");
                          _mxLogger.info("这是info信息");
                          _mxLogger.warn("这是warn信息");
                          _mxLogger.error("这是error信息");
                          _mxLogger.fatal("这是fatal信息");
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
                    ElevatedButton(onPressed: (){
                      MXAnalyzer.dismiss();
                    },child: Text("隐藏调试"),),
                    ElevatedButton(onPressed: (){
                      Navigator.of(context).push(MaterialPageRoute(builder: (context){
                        return SecondPage();
                      }));
                    }, child: Text("进入二级页面"))
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
      appBar: AppBar(title: Text("second"),),
      backgroundColor: Colors.white,
      body: Center(
        child: Text("这是push进来的页面"),
      ),
    );
  }
}

