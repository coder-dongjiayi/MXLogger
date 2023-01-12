import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: Colors.white,
          body:Builder(builder: (context){
            return Center(
              child: GestureDetector(
                onTap: (){
                  MXAnalyzerLib_showDebug(context);
                },
                child: Icon(Icons.bug_report,color: Colors.blue,size: 50,),
              ),
            );
          },)),
    );
  }
}
