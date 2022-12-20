import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/component/mxlogger_text.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_provider.dart';

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
            return Container(
                margin: EdgeInsets.all(10),
                color:
                index % 2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,
                child:MXLoggerText(
                  text: source[index],
                  style: TextStyle(color: MXTheme.text),
                )
            );
          },
          itemCount: source.length,
          physics: const AlwaysScrollableScrollPhysics(),
        );
      },),
    );
  }

  @override
  // TODO: implement wantKeepAlive
  bool get wantKeepAlive => true;
}
