import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
import 'package:flutter_mxlogger/src/widget/log_listview.dart';
import 'package:flutter_mxlogger/src/widget/search_bar.dart';

class MXLoggerLogPage extends StatefulWidget {
  const MXLoggerLogPage({Key? key, required this.logPath, required this.fileSize}) : super(key: key);
  final String logPath;
  final int fileSize;
  @override
  _MXLoggerLogPageState createState() => _MXLoggerLogPageState();
}

class _MXLoggerLogPageState extends State<MXLoggerLogPage> {
  List<Map<String, dynamic>> dataSource = [];
  int offSize = 0;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    loadMoreData();
  }

  void loadMoreData(){
    if(offSize>= widget.fileSize) return;
    MXLogger.selectLogMsg(
        diskcacheFilePath: widget.logPath,
        offSize: offSize,
        limit: 10,
        completion: (int size, List<String> messages) {
    
          List<Map<String, dynamic>> _list = [];
          for (var element in messages) {
            Map<String,dynamic> map = jsonDecode(element);
            if(map["header"] == null){
              _list.add(map);
            }
          }

         if(offSize == 0){
           dataSource = _list;
         }else{
           dataSource.addAll(_list);
         }
          offSize = size + offSize;
        });
    setState(() {

    });
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
      body: LogListView(
        dataSource: dataSource,
        loadMoreBack: (){
          loadMoreData();
        },
      ),
    );
  }
}
