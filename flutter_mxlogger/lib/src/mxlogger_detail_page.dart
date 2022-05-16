import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
import 'package:flutter_mxlogger/src/level/mx_level.dart';
class MXLoggerDetailPage extends StatefulWidget {
  const MXLoggerDetailPage({Key? key, required this.source}) : super(key: key);
  final Map<String,dynamic> source;
  @override
  _MXLoggerDetailPageState createState() => _MXLoggerDetailPageState();
}

class _MXLoggerDetailPageState extends State<MXLoggerDetailPage> {
 late Map<String,dynamic> _source;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _source = widget.source;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: MXTheme.themeColor,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          name(_source["name"]),
          SizedBox(height: 10),
          level(levelName(_source["level"])),
          SizedBox(height: 10),
          time(_source["time"]),
          SizedBox(height: 10),
          thread("${_source["thread_id"]}",_source["is_main_thread"]),
          SizedBox(height: 10),
          message(_source["msg"])
        ],
      ),
      
    );
  }
 Widget name(String name){
   return Text("name:$name",style: TextStyle(color: MXTheme.text));
 }
 Widget level(String  levelName){
   return Text("级别:$levelName",style: TextStyle(color: MXTheme.text));
 }
  Widget time(String time){
    return Text("时间:$time",style: TextStyle(color: MXTheme.text));
  }
  Widget thread(String threadId,bool isMain){
    return Row(
      children: [
        Text("线程ID:89992 是否为主线程:$isMain",style: TextStyle(color: MXTheme.text))
      ],
    );
  }
  Widget message(String msg){
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
      color: MXTheme.itemBackground,
      child: Text(msg,style: TextStyle(color: MXTheme.text,fontSize: 16)),
    );
  }
}

