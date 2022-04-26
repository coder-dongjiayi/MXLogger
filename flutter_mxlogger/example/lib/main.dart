
import 'package:flutter/material.dart';

import 'package:flutter_mxlogger/flutter_mxlogger.dart';

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
  @override
  void initState() {
    super.initState();
  init();
  }

  void init() async{

    logger =  await MXLogger.initialize(nameSpace: "flutter_mxlogger",enable: true);
   
    String  isDebug =  logger.isDebugTraceing() == true ? "正在调试" : "非调试状态";
    logger.info(isDebug,name: "mxlogger",tag: "isDebug");
    
    String? diskCachePath = logger.getdDiskcachePath();
    if(diskCachePath == null){
      logger.error("diskCachePath 异常");
    }else{
      logger.info(diskCachePath,name: "mxlogger",tag: "path");
    }

    logger.setMaxdiskSize(1024*1024*10);
    logger.setMaxdiskAge(60*60*24*7);

  /// 以下都是默认设置
    logger.setStoragePolicy("yyy_MM_dd");
    logger.setFileName("mxlog");
    logger.shouldRemoveExpiredDataWhenEnterBackground(true);
    logger.setConsoleLevel(0);
    logger.setFileLevel(1);
    logger.setConsolePattern("[%d][%p]%m");
    logger.setFilePattern("[%d][%t][%p]%m");
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
                logger.debug("这是debug数据");

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
              ElevatedButton(onPressed: () async{

                for(int i= 0;i < 100000;i++){
                  logger.info("这是第${i}条数据",tag: "tag");
                }

              }, child: Text("10万条数据"))
            ],
          )
        ),
      ),
    );
  }
}
