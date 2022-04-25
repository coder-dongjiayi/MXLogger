
import 'package:flutter/material.dart';

import 'package:flutter_mxlogger/flutter_mxlogger.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await MXLogger.initialize(nameSpace: "flutter",enable: true);
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
              ElevatedButton(onPressed: () async{
               String? zipPath = await MXLogger.compressLogFile();
               if(zipPath != null){
                 print("zipPath:${zipPath}");
               }

              }, child: Text("压缩文件夹"))
            ],
          )
        ),
      ),
    );
  }
}
