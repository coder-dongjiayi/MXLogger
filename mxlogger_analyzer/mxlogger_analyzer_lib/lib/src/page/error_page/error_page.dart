import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/src/component/mxlogger_text.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider_2.dart';

import '../../theme/mx_theme.dart';


class ErrorPage extends StatefulWidget {
  const ErrorPage({Key? key}) : super(key: key);

  @override
  State<ErrorPage> createState() => _ErrorPageState();
}

class _ErrorPageState extends State<ErrorPage>  with AutomaticKeepAliveClientMixin{

  @override
  Widget build(BuildContext context) {
  super.build(context);
    return Scaffold(
      backgroundColor: MXTheme.themeColor,
      body: Consumer(builder: (context, ref,_){
      List<String> source =   ref.watch(errorListProvider);
        return ListView.builder(
          controller: ScrollController(),
          itemBuilder: (context, index) {
            return GestureDetector(onTap: (){
              _copyClipboard(context,source[index]);
            },child: Container(
                margin: EdgeInsets.all(10),
                color:
                index % 2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,
                child:MXLoggerText(
                  text: source[index],
                  style: TextStyle(color: MXTheme.text),
                )
            ));
          },
          itemCount: source.length,
          physics: const AlwaysScrollableScrollPhysics(),
        );
      },),
    );
  }
  void _copyClipboard(BuildContext context, String msg) {
    Clipboard.setData(ClipboardData(text: msg));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: MXTheme.warn,
      content: Text(
        "错误信息已复制到剪切板",
        textAlign: TextAlign.center,
        style: TextStyle(color: MXTheme.white, fontSize: 18),
      ),
    ));
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
