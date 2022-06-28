
import 'package:flutter/material.dart';




import 'log_page.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();

  }


  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      home: Builder(builder: (context){
        return Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Center(
              child:ElevatedButton(onPressed: (){
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) {
                  return LogPage();
                }));
              },child: Text("进入日志页面"))
          ),
        );
      })
    );
  }
}
