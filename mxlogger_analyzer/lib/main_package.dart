import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

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

  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.white,
          body: Builder(
            builder: (context) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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
                    GestureDetector(
                      onTap: () {
                        MXAnalyzerLib_showDebug(context,
                            diskcachePath: _mxLogger.diskcachePath,
                            cryptKey: _cryptKey,
                            iv: _iv);
                      },
                      child: Icon(
                        Icons.bug_report,
                        color: Colors.blue,
                        size: 50,
                      ),
                    )
                  ],
                ),
              );
            },
          )),
    );
  }
}
