
import 'package:flutter/material.dart';

import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger_analyzer/flutter_mxlogger_analyzer.dart' as Analyzer;
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
 late MXLogger logger;
 late String _diskCachePath;
  @override
  void initState() {
    super.initState();
  init();
  }

  void init() async{

    logger =  await MXLogger.initialize(nameSpace: "flutter_mxlogger",enable: true);
   


    Map<String,dynamic> header = {"version":"1.0.1","platform":"ios"};
    logger.setFileHeader(header);

    logger.setMaxdiskSize(1024*1024*10);
    logger.setMaxdiskAge(60*60*24*7);

    logger.setStoragePolicy("yyyy_MM_dd_HH");
    logger.setFileName("mxlog");
    logger.shouldRemoveExpiredDataWhenEnterBackground(true);
    logger.setConsoleLevel(0);
    logger.setFileLevel(0);
    logger.setPattern("[%d][%p]%m");

    // String  isDebug =  logger.isDebugTraceing() == true ? "正在调试" : "非调试状态";
    // logger.info(isDebug,name: "mxlogger",tag: "isDebug");
    //
    // String? diskCachePath = logger.getdDiskcachePath();
    // if(diskCachePath == null){
    //   logger.error("diskCachePath 异常");
    // }else{
    //   _diskCachePath =  diskCachePath;
    //   logger.info(diskCachePath,name: "mxlogger",tag: "path");
    // }
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
                logger.debug("这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据这是debug数据");

              }, child: Text("debug")),
              ElevatedButton(onPressed: (){
                logger.info("这是info数据",name: "flutter",tag: "tag");

              }, child: Text("info")),
              ElevatedButton(onPressed: (){
                logger.warn("这是warn数据");

              }, child: Text("warn")),
              ElevatedButton(onPressed: (){
                logger.error("这是erro数据");

              }, child: Text("error")),
              ElevatedButton(onPressed: (){
              List<Map<String, dynamic>> _list =  MXLogger.selectLogfiles(directory: _diskCachePath);
              _list.forEach((element) {
                print(element.toString());
              });

              }, child: Text("获取目录下的日志文件")),

              ElevatedButton(onPressed: (){
                // List<Map<String, dynamic>> _list =  MXLogger.selectLogfiles(directory: _diskCachePath);
                // String fileName = _list.first["name"];
                //
                // MXLogger.selectLogMsg(diskcacheFilePath: _diskCachePath + fileName,completion: (int size,List<String> messageList){
                //   print("size = $size");
                //   messageList.forEach((element) {
                //     print(element);
                //
                //   });
                //
                // });

              }, child: Text("查询日志信息")),
              Builder(builder: (context){
                return ElevatedButton(onPressed: (){

                  Analyzer.show(context, logger.getDiskcachePath() ?? "");
                }, child: Text("分析器"));
              })
            ],
          )
        ),
      ),
    );
  }
}
