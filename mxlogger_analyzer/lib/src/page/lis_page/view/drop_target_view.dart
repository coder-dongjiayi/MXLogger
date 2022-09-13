import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';
class DropTargetView extends StatefulWidget {
  const DropTargetView({Key? key}) : super(key: key);

  @override
  State<DropTargetView> createState() => _DropTargetViewState();
}

class _DropTargetViewState extends State<DropTargetView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 20),
      alignment: Alignment.bottomCenter,
      color: MXTheme.dropTargetColor,
      child:  Text("松手以导入数据",style: TextStyle(fontSize: 16,color: MXTheme.white),),
    );
  }
}
