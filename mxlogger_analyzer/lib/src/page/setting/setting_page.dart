import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../component/mxlogger_button.dart';
import '../../component/mxlogger_text.dart';
import '../../theme/mx_theme.dart';
class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor:  MXTheme.themeColor,
      body: Container(
        margin: const EdgeInsets.only(top: 20,left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MXLoggerButton(text: "清空数据",onPressed: (){
              showAlert();
            }),
            SizedBox(height: 20),

            MXLoggerText(text: "设置AES",titleStyle: TitleStyle.title,),

            SizedBox(height: 10),
            SizedBox(width: 200,height: 35, child: CupertinoTextField(
              placeholder: "KEY",
            )),
            SizedBox(height: 10),
            SizedBox(width: 200,height: 35, child: CupertinoTextField(
              placeholder: "IV",
            ))
          ],
        ),
      )
    );
  }

  void showAlert(){
    showDialog(context: context, builder: (context){
      return CupertinoAlertDialog(
        title: Text("提示"),
        content:Text("你确定要清空数据库么") ,
        actions: [
          CupertinoDialogAction(
            child: Text("取消"),
            onPressed: (){
            Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text("清空"),
            onPressed: (){

            },
          )
        ],
      );
    });
  }
}
