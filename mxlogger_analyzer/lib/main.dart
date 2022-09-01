

import 'package:flutter_side_menu/flutter_side_menu.dart';

import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_list_page.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await AnalyzerDatabase.initDataBase();
  await MXLoggerStorage.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

  }

  @override
  Widget build(BuildContext context) {
   // return LogListPage();
    return  Scaffold(

      body: Row(
        children: [
          SideMenu(
            backgroundColor: MXTheme.sliderColor,
            position: SideMenuPosition.left,
           hasResizer: false,
          hasResizerToggle: false,
            maxWidth: 60,
            minWidth: 60,
            builder: (data) {
              return SideMenuData(
                footer: GestureDetector(
                  onTap: (){

                  },
                  child: Container(
                    margin: EdgeInsets.only(bottom: 20),
                    child: Icon(Icons.settings,color: Colors.white),
                  ),
                ),
                items: [
                  SideMenuItemDataTile(
                    unSelectedColor: Colors.transparent,
                    selectedColor: Colors.transparent,
                    highlightSelectedColor: Colors.transparent,
                    isSelected: true,
                    onTap: () {},
                    icon: const Icon(Icons.home,color: Colors.white),
                  ),

                ],
              );
            },
          ),
          Expanded(child: const LogListPage())
        ],
      ),

    );
  }
}
