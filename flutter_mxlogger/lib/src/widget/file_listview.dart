import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';

typedef FileItemTapCallback = void Function(String fileName,int size);

class FileListView extends StatefulWidget {
   const FileListView({Key? key,required this.dirPath,this.callback}) : super(key: key);

  final  String dirPath;
  final FileItemTapCallback? callback;
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
       DateTime  dateTime =  DateTime.fromMillisecondsSinceEpoch(timeStemp * 1000);

      return   GestureDetector(
          onTap: (){
            widget.callback?.call(name,size);
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            color:
            index % 2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,

            child: _itemBuiler(name,dateTime.toString(),_kbString(size)),
          ));
    });
  }

  String _kbString(int size){
    if(size < 1024){
      return "$size B";
    }
    double M = 1024.0*1024;

    if(size > 1024 && size< M){
      double sizeK = size/1024.0;
      return sizeK.toStringAsFixed(2) + "K";
    }

    double G = M * 1024.0;
    if(size > M && size < G){
      double sizeM =  size/M;
      return sizeM.toStringAsFixed(2) + "M";
    }
    if(size > G){
      double sizeG = size / G;
      return sizeG.toStringAsFixed(2) + "G";
    }
    return "$size Byte";
  }

  Widget _itemBuiler(String name,String time,String kb){
    return  Row(
      children: [
        Icon(Icons.insert_drive_file_outlined,size: 25,color: MXTheme.white),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text("$name",style: TextStyle(color: MXTheme.white,fontSize: 17)),
          const SizedBox(height: 10),
          Text("last time:$time",style: TextStyle(color: MXTheme.text,fontSize: 12),)
        ],)),
        Text("$kb",style: TextStyle(color: MXTheme.text))
      ],
    );
  }
}
