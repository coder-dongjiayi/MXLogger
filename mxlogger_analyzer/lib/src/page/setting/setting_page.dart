import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';

import '../../component/mxlogger_button.dart';
import '../../component/mxlogger_text.dart';
import '../../component/mxlogger_textfield.dart';

import '../../provider/mxlogger_repository.dart';
import '../../provider/mxlogger_provider.dart';
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
    keyController =
        TextEditingController(text: MXLoggerStorage.instance.cryptKey);
    ivController =
        TextEditingController(text: MXLoggerStorage.instance.cryptIv);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: MXTheme.themeColor,
        body: Container(
          margin: const EdgeInsets.only(top: 20, left: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MXLoggerText(
                text: "数据库路径:${MXLoggerStorage.instance.databasePath}",
                style: TextStyle(color: MXTheme.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  MXLoggerButton(
                      text: "清空数据",
                      onPressed: (ref) {
                        showAlert(ref);
                      }),
                  const SizedBox(width: 20),
                  MXLoggerButton(
                      text: "复制数据库路径",
                      onPressed: (ref) {
                        Clipboard.setData(ClipboardData(
                            text: MXLoggerStorage.instance.databasePath));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: MXTheme.warn,
                          content: Text(
                            "内容已复制到剪切板",
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: MXTheme.white, fontSize: 18),
                          ),
                        ));
                      }),
                ],
              ),
              const SizedBox(height: 20),
              const MXLoggerText(
                text: "设置AES",
                titleStyle: TitleStyle.title,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 200,
                height: 35,
                child: MXLoggerTextField(
                  controller: keyController,
                  hintText: "CryptKey",
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                  width: 200,
                  height: 35,
                  child: MXLoggerTextField(
                    controller: ivController,
                    hintText: "CryptIv",
                  )),
              const SizedBox(height: 10),
              MXLoggerButton(
                  text: "确定修改",
                  onPressed: (ref) {
                    ref.read(mxloggerRepository).saveAES(
                        cryptKey: keyController.text.trim(),
                        iv: ivController.text.trim());
                  }),
              const SizedBox(height: 10),
              Row(
                children: [
                  Consumer(builder: (context, ref, _) {
                    var config = ref.watch(cryptAlertProvider);
                    return Checkbox(
                        value: config,
                        activeColor: MXTheme.debug,
                        onChanged: (value) {
                          ref.read(cryptAlertProvider.notifier).state = value;
                        });
                  }),
                  MXLoggerText(
                    text: "拖入日志文件不再提示输入key和iv",
                    style: TextStyle(color: MXTheme.text),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              MXLoggerText(
                text: "日志导入失败可能的原因",
                style: TextStyle(color: MXTheme.error),
              ),
              const SizedBox(
                height: 10,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MXLoggerText(
                    text: "1.检查设置的key和iv是否一致",
                    style: TextStyle(color: MXTheme.text),
                  ),
                  MXLoggerText(
                    text: "2.检查设置的key和iv是否为16个字母(或者正好为128位)",
                    style: TextStyle(color: MXTheme.text),
                  ),
                  MXLoggerText(
                    text: "3.导入数据是否重复(标记数据重复的依据是日志写入时生成的时间戳(微妙级))",
                    style: TextStyle(color: MXTheme.text),
                  ),
                ],
              )
            ],
          ),
        ));
  }

  void showAlert(WidgetRef ref) {
    showDialog(
        context: context,
        builder: (_context) {
          return CupertinoAlertDialog(
            title: Text("提示"),
            content: Text("你确定要清空数据库么"),
            actions: [
              CupertinoDialogAction(
                child: Text("取消"),
                onPressed: () {
                  Navigator.of(_context).pop();
                },
              ),
              CupertinoDialogAction(
                child: Text("清空"),
                onPressed: () async {
                  await ref.read(mxloggerRepository).deleteData();

                  ref.read(selectedIndexProvider.notifier).state = 0;

                  ref.invalidate(logPagesProvider);

                  Navigator.of(_context).pop();
                },
              )
            ],
          );
        });
  }
}
