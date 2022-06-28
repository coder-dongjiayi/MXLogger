import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

import 'log_list_page.dart';

class LogPage extends StatefulWidget {
  const LogPage({Key? key}) : super(key: key);

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  late MXLogger _mxLogger;
  int _size = 0;
  final String _cryptKey = "mxloggeraes128cryptkey";
  final String _iv = "mxloggeraescfbiv";
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    init();
  }

  Future<void> init() async {
    _mxLogger = await MXLogger.initialize(
        nameSpace: "flutter.mxlogger",
        cryptKey: _cryptKey,
        iv: _iv);
    _mxLogger.setMaxdiskAge(60*60*24*7);
    _mxLogger.setMaxdiskSize(1024*1024*10);
    _mxLogger.setConsoleEnable(true);
    updateSize();

    print("path:${_mxLogger.getDiskcachePath()}");
  }

  @override
  void dispose() {
    // TODO: implement dispose
    MXLogger.destroy(nameSpace: "flutter.mxlogger");
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
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return LogListPage(
                      dirPath: _mxLogger.getDiskcachePath(),
                      cryptKey: _cryptKey,
                      iv: _iv,
                    );
                  }));
                },
                child: Text("查看日志"),
              ),
              ElevatedButton(
                  onPressed: () {

                    _mxLogger.info("这是info数据", name: "mxlogger", tag: "i");
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
    _size = _mxLogger.logSize();
    setState(() {});
  }
}
