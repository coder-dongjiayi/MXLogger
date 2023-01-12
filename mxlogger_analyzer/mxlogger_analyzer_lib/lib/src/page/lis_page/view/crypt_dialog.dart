import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/storage/mxlogger_storage.dart';

class CryptDialog extends StatefulWidget {
  const CryptDialog({Key? key}) : super(key: key);
  @override
  State<CryptDialog> createState() => _CryptDialogState();

  static Future<bool?> show(BuildContext context) async {
    return showDialog<bool>(
        context: context,
        builder: (context) {
          return CryptDialog();
        });
  }
}

class _CryptDialogState extends State<CryptDialog> {
  late TextEditingController _aesKeyController;
  late TextEditingController _aesIvController;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _aesKeyController =
        TextEditingController(text: MXLoggerStorage.instance.cryptKey);
    _aesIvController =
        TextEditingController(text: MXLoggerStorage.instance.cryptIv);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text("请输入AES密钥"),
      content: Container(
        margin: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            CupertinoTextField(
              controller: _aesKeyController,
              placeholder: "KEY",
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: _aesIvController,
              placeholder: "IV",
            ),

          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          child: const Text("确定"),
          onPressed: () async {

            await MXLoggerStorage.instance.saveAES(
                cryptKey: _aesKeyController.text, iv: _aesIvController.text);
            Navigator.of(context).pop(true);
          },
        ),
        CupertinoDialogAction(
          child: const Text("取消"),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        )
      ],
    );
  }
}
