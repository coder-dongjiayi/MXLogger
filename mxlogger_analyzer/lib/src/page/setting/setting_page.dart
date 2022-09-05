import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';
import 'package:provider/provider.dart';

import '../../component/mxlogger_button.dart';
import '../../component/mxlogger_text.dart';
import '../../component/mxlogger_textfield.dart';
import '../../controller/mxlogger_controller.dart';
import '../../theme/mx_theme.dart';
class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {

  late TextEditingController keyController;
  late TextEditingController ivController;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    keyController = TextEditingController(text: MXLoggerStorage.instance.cryptKey);
    ivController  = TextEditingController(text: MXLoggerStorage.instance.cryptIv);
  }
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
            const SizedBox(height: 20),

            const MXLoggerText(text: "设置AES",titleStyle: TitleStyle.title,),

            const SizedBox(height: 10),
           SizedBox(width: 200,height: 35,child:   MXLoggerTextField(controller: keyController, hintText: "CryptKey",),),

            const SizedBox(height: 10),
            SizedBox(width: 200,height: 35, child: MXLoggerTextField(controller: ivController, hintText: "CryptIv",)),
            const SizedBox(height: 10),
            MXLoggerButton(text: "确定修改",onPressed: (){

              MXLoggerStorage.instance.saveAES(cryptKey: keyController.text.trim(),iv: ivController.text.trim());

            }),
          ],
        ),
      )
    );
  }

  void showAlert(){
    showDialog(context: context, builder: (_context){
      return CupertinoAlertDialog(
        title: Text("提示"),
        content:Text("你确定要清空数据库么") ,
        actions: [
          CupertinoDialogAction(
            child: Text("取消"),
            onPressed: (){
            Navigator.of(_context).pop();
            },
          ),
          CupertinoDialogAction(
            child: Text("清空"),
            onPressed: () async{

              await AnalyzerDatabase.deleteData();
              context.read<MXLoggerController>().deleteData();

              Navigator.of(_context).pop();
            },
          )
        ],
      );
    });
  }
}
