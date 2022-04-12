
import 'package:flutter/material.dart';

import 'package:flutter_mxlogger/flutter_mxlogger.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await MXLogger.initialize(enable: true);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

   String? path =   MXLogger.getdDiskcachePath();
   MXLogger.debug("日志磁盘路径为:$path");
    int size =  MXLogger.logSize();
    MXLogger.debug("日志文件大小:$size byte");

    /**下面这些设置都是默认设置 不写也行 **/
    MXLogger.setFileName("mxlog");
    MXLogger.shouldRemoveExpiredDataWhenEnterBackground(true);
    MXLogger.setStoragePolicy("yyyy_MM_dd");
    MXLogger.setFileLevel(1);
    MXLogger.setConsoleLevel(0);
    MXLogger.setFileEnable(true);
    MXLogger.setConsoleEnable(true);
    MXLogger.setFilePattern("[%d][%t][%p]%m");
    MXLogger.setConsolePattern("[%d][%p]%m");
    MXLogger.setAsync(true);

  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [

              ElevatedButton(onPressed: (){
                MXLogger.debug("这是debug数据");

              }, child: Text("debug")),
              ElevatedButton(onPressed: (){
                MXLogger.info("这是info数据");

              }, child: Text("info")),
              ElevatedButton(onPressed: (){
                MXLogger.warn("这是warn数据");

              }, child: Text("warn")),
              ElevatedButton(onPressed: (){
                MXLogger.error("这是erro数据");

              }, child: Text("error")),
              ElevatedButton(onPressed: (){
                MXLogger.fatal("这是fatal数据");

              }, child: Text("fatal"))
            ],
          )
        ),
      ),
    );
  }
}
