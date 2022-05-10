import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger/src/widget/file_listview.dart';
import 'package:flutter_mxlogger/src/widget/log_listview.dart';
import 'package:flutter_mxlogger/src/widget/search_bar.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';

import 'mxlogger_detail_page.dart';
import 'mxlogger_log_page.dart';

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


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initFileData();
  }
  Future<void> initFileData() async {
    MXLogger.selectLogfiles(directory: widget.logDir);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,

      body: FileListView(
       dirPath: widget.logDir,
        callback: (String fileName,int size){
         String path = widget.logDir + fileName;

          Navigator.push(context, MaterialPageRoute(builder: (context){
            return MXLoggerLogPage(
              logPath: path,
              fileSize: size,
            );
          }));
        },
      ),


    );
  }
}

