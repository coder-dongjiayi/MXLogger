

import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_binary.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_list_page.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyzerDatabase.initDataBase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
   // return LogListPage();
    return  Scaffold(

      body: LogListPage(),
      // body: Center(
      //     child: ElevatedButton(
      //         onPressed: () async{
      //           XFile? file = await openFile(
      //               initialDirectory: "/Users/dongjiayi/Desktop/log");
      //           Uint8List? data = await file?.readAsBytes();
      //           if (data == null) return;
      //           AnalyzerBinary.loadData(binaryData: data);
      //         },
      //         child: Text("选择日志文件"))),
    );
  }
}
