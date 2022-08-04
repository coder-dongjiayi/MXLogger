import 'package:flutter/material.dart';

class CryptDialog extends StatelessWidget {
  const CryptDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async{
    return showDialog(context: context, builder: (context){
      return CryptDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Column(
      children: [

      ],
    ),
    );
  }
}
