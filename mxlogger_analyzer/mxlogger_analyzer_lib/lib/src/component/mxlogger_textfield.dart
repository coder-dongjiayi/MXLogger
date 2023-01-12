import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';
class MXLoggerTextField extends StatelessWidget {
  const MXLoggerTextField({Key? key, this.hintText, this.controller}) : super(key: key);
  final String?  hintText;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: MXTheme.buttonColor,width: 1)
      ),
      padding: EdgeInsets.only(bottom: 5,left: 10,right: 10),
      child: TextField(
        controller: controller,
        style: TextStyle(color:MXTheme.text),
        decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: MXTheme.subText),
            border: InputBorder.none,


        ),
      ),
    );
  }
}
