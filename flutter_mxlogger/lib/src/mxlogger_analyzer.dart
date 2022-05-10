import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger/src/widget/file_listview.dart';
import 'package:flutter_mxlogger/src/widget/log_listview.dart';
import 'package:flutter_mxlogger/src/widget/search_bar.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';

import 'mxlogger_detail_page.dart';

void show(BuildContext context,String dir) {
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color.fromRGBO(0, 0, 0, 0),
      builder: (_) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width,
          child:  MXLoggerAnalyzer(logDir: dir),
        );
      });
}

class MXLoggerAnalyzer extends StatefulWidget {
   MXLoggerAnalyzer({Key? key,required this.logDir}) : super(key: key);
  String logDir;
  @override
  _MXLoggerAnalyzerState createState() => _MXLoggerAnalyzerState();
}

class _MXLoggerAnalyzerState extends State<MXLoggerAnalyzer> {

 late List<Map<String,dynamic>> dataSource;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initFileData();
    dataSource = [
      {
        "level":0,
        "msg":"这是一条debug信息，请前往AppStore查看对账单"
      },
      {
        "level":1,
        "msg":"这是一条info信息，请前往AppStore查看对账单"
      },
      {
        "level":1,
        "msg":"这是一条info信息，请前往AppStore查看对账单"
      },
      {
        "level":1,
        "msg":"这是一条info信息，请前往AppStore查看对账单"
      },
      {
        "level":1,
        "msg":"这是一条info信息，请前往AppStore查看对账单"
      },
      {
        "level":1,
        "msg":"这是一条info信息，请前往AppStore查看对账单"
      },

      {
        "level":2,
        "msg":"这是一条warn信息，请前往AppStore查看对账单"
      },
      {
        "level":3,
        "msg":"这是一条error信息，请前往AppStore查看对账单"
      },
      {
        "level":4,
        "msg":"这是一条fatal信息，请前往AppStore查看对账单"
      }
    ];
  }

  Future<void> initFileData() async {
    MXLogger.selectLogfiles(directory: widget.logDir);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: AppBar(
        leadingWidth: 0,
        toolbarHeight: 90,
        backgroundColor: MXTheme.itemBackground,
        elevation: 0,
        leading: const SizedBox(),
        title: const SearchBar(),
      ),
      body: FileListView(
       dirPath: widget.logDir,
      ),
      // body: LogListView(
      //   dataSource: dataSource,
      //   callback: (index){
      //     Navigator.of(context).push(MaterialPageRoute(builder: (context){
      //       return MXLoggerDetailPage();
      //     }));
      //   },
      // ),

    );
  }
}

