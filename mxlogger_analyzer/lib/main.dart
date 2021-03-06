import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:mxlogger_analyzer/analyzer_database.dart';

import 'analyzer_binary.dart';

void main() {
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
    loadData();
  }

  void loadData() async {
    await AnalyzerDatabase.initDataBase();
    AnalyzerDatabase.insertData(
        isMainThread: 1,
        timestamp: 888888,
        name: "mxlogger",
        tag: "net,full",
        level: 1,
         msg: "这是一条信息"
    );
    AnalyzerDatabase.insertData(
        isMainThread: 1,
        timestamp: 888888,
        name: "mxlogger",
        tag: "net,full",
        level: 1,
        msg: "这是二条信息"
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: ElevatedButton(
              onPressed: () async {
                XFile? file = await openFile(
                    initialDirectory: "/Users/dongjiayi/Desktop/log");
                Uint8List? data = await file?.readAsBytes();
                if (data == null) return;
                AnalyzerBinary.decode(binaryData: data);
              },
              child: Text("选择日志文件"))),
    );
  }
}
