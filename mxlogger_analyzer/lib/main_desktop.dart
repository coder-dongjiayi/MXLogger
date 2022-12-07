import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_side_menu/flutter_side_menu.dart';

import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';

import 'package:mxlogger_analyzer/src/controller/mxlogger_provider.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_list_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/drop_target_view.dart';
import 'package:mxlogger_analyzer/src/page/setting/setting_page.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MXLoggerStorage.instance.initialize();
  await AnalyzerDatabase.initDataBase(MXLoggerStorage.instance.databasePath);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
      builder: EasyLoading.init(),
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

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
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
                  header: Container(
                    margin: EdgeInsets.only(top: 5),
                    child: Image.asset(
                      "assets/images/logo.png",
                      width: 35,
                      height: 35,
                    ),
                  ),
                  footer: GestureDetector(
                    onTap: () {
                      ref.read(selectedIndexProvider.notifier).state = 1;
                    },
                    child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Consumer(
                          builder: (context, ref, _) {
                            int index = ref.watch(selectedIndexProvider);

                            return Icon(Icons.settings,
                                color: index == 1
                                    ? MXTheme.white
                                    : MXTheme.subText);
                          },
                        )),
                  ),
                  items: [
                    SideMenuItemDataTile(
                      unSelectedColor: Colors.transparent,
                      selectedColor: Colors.transparent,
                      highlightSelectedColor: Colors.transparent,
                      isSelected: true,
                      onTap: () {
                        ref.read(selectedIndexProvider.notifier).state = 0;
                      },
                      icon: Consumer(
                        builder: (context, ref, _) {
                          int index = ref.watch(selectedIndexProvider);

                          return Icon(Icons.home,
                              color:
                                  index == 0 ? MXTheme.white : MXTheme.subText);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            Expanded(
                child: Stack(
              children: [
                PageView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: ref.read(pageControllerProvider),
                    itemCount: _dataSource.length,
                    scrollDirection: Axis.vertical,
                    itemBuilder: (context, index) {
                      return _dataSource[index];
                    }),
                Consumer(builder: (context, ref, _) {
                  bool visible = ref.watch(dropTargetProvider);
                  return Visibility(
                      visible: visible, child: const DropTargetView());
                })
              ],
            ))
          ],
        ),
      );
    });
  }
}
