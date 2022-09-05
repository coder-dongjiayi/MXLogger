import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';

enum TitleStyle{
  title,
  subtitle
}

class MXLoggerText extends StatelessWidget {
  const MXLoggerText({Key? key, required this.text, this.titleStyle}) : super(key: key);
   final String text;
   final TitleStyle? titleStyle;
  @override
  Widget build(BuildContext context) {

    return Text(text,style: TextStyle(color: MXTheme.white,fontSize: _fontSize()));
  }

  double _fontSize(){
    if(titleStyle == TitleStyle.title){
      return 16;
    }
    if(titleStyle == TitleStyle.subtitle){
      return 14;
    }
    return 14;
  }
}
