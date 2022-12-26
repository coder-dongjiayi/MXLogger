import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_side_menu/flutter_side_menu.dart';
import 'package:mxlogger_analyzer/src/page/error_page/error_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/log_list_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/drop_target_view.dart';
import 'package:mxlogger_analyzer/src/page/setting/setting_page.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';

class DesktopPage extends ConsumerWidget {
  DesktopPage({Key? key}) : super(key: key);
  final List<Widget> _dataSource = [
    const LogListPage(),
    const ErrorPage(),
    const SettingPage()
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: MXTheme.sliderColor,
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
                  margin: const EdgeInsets.only(top: 5),
                  child: Image.asset(
                    "assets/images/logo.png",
                    width: 35,
                    height: 35,
                  ),
                ),
                footer: GestureDetector(
                  onTap: () {
                    ref.read(selectedIndexProvider.notifier).state = 2;
                  },
                  child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Consumer(
                        builder: (context, ref, _) {
                          int index = ref.watch(selectedIndexProvider);

                          return Icon(Icons.settings,
                              color:
                                  index == 2 ? MXTheme.white : MXTheme.subText);
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
                  SideMenuItemDataTile(
                      isSelected: false,
                      onTap: () {
                        ref.read(selectedIndexProvider.notifier).state = 1;
                      },
                      icon: Consumer(
                        builder: (context, ref, _) {
                          int index = ref.watch(selectedIndexProvider);
                          return Icon(
                            Icons.error_outline_sharp,
                            color: index == 1 ? MXTheme.white : MXTheme.subText,
                          );
                        },
                      ))
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
  }
}
