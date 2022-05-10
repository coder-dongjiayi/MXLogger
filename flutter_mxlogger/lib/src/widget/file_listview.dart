import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
class FileListView extends StatefulWidget {
   const FileListView({Key? key,required this.dirPath}) : super(key: key);

  final  String dirPath;
  @override
  _FileListViewState createState() => _FileListViewState();
}

class _FileListViewState extends State<FileListView> {

  List<Map<String,dynamic>> _dataSource = [];
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _dataSource =  MXLogger.selectLogfiles(directory: widget.dirPath);
  }

  @override
  Widget build(BuildContext context) {

    return ListView.builder(itemCount: _dataSource.length, itemBuilder: (context,index){
      Map<String,dynamic> map = _dataSource[index];
      String name = map["name"];
      int timeStemp = map["timestemp"];
      int size = map["size"];

      return   GestureDetector(
          onTap: (){

          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            color:
            index % 2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,

            child: _itemBuiler(name,"$timeStemp","$size"),
          ));
    });
  }

  Widget _itemBuiler(String name,String time,String kb){
    return  Row(
      children: [
        Icon(Icons.insert_drive_file_outlined,size: 25,color: MXTheme.white),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text("$name",style: TextStyle(color: MXTheme.white,fontSize: 16)),
          const SizedBox(height: 10),
          Text("last time:$time",style: TextStyle(color: MXTheme.text,fontSize: 12),)
        ],)),
        Text("$kb",style: TextStyle(color: MXTheme.text))
      ],
    );
  }
}
