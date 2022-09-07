import 'package:flutter_side_menu/flutter_side_menu.dart';

import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_controller.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_list_page.dart';
import 'package:mxlogger_analyzer/src/page/setting/setting_page.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
void main() async {
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
    return  MaterialApp(
      home: MyHomePage(),
      builder:EasyLoading.init(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<Widget> _dataSource = [const LogListPage(), const SettingPage()];
  PageController _pageController = PageController(initialPage: 0);
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(providers: [
      ChangeNotifierProvider(create: (_)=> MXLoggerController()),
    ],builder: (context,_){
      return Scaffold(
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
                    onTap: () {

                      _pageController.jumpToPage(1);
                      context.read<MXLoggerController>().setSelectedIndex(1);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Builder(builder: (context){
                        int index =  context.select<MXLoggerController,int>((value) => value.selectedIndex);
                        return Icon(Icons.settings, color: index == 1 ? MXTheme.white :MXTheme.subText);
                      },),
                    ),
                  ),
                  items: [
                    SideMenuItemDataTile(
                      unSelectedColor: Colors.transparent,
                      selectedColor: Colors.transparent,
                      highlightSelectedColor: Colors.transparent,
                      isSelected: true,
                      onTap: () {
                        _pageController.jumpToPage(0);
                        context.read<MXLoggerController>().setSelectedIndex(0);
                      },
                      icon: Builder(builder: (context){
                        int index =  context.select<MXLoggerController,int>((value) => value.selectedIndex);
                        return Icon(Icons.home, color: index == 0 ? MXTheme.white :MXTheme.subText);
                      }),
                    ),
                  ],
                );
              },
            ),

            Expanded(
                child: PageView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    controller: _pageController,
                    itemCount: _dataSource.length,

                    scrollDirection: Axis.vertical,
                    itemBuilder: (context, index) {
                      return _dataSource[index];
                    }))
          ],
        ),
      );
    },);
  }
}
