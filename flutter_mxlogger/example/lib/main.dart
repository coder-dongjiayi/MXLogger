
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


    logger =  await MXLogger.initialize(nameSpace: "flutter",enable: true);
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
               // String? zipPath = await MXLogger.compressLogFile();
               // if(zipPath != null){
               //   print("zipPath:${zipPath}");
               // }

              }, child: Text("压缩文件夹"))
            ],
          )
        ),
      ),
    );
  }
}
