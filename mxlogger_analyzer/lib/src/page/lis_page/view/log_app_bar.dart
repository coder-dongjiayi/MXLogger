import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer/src/controller/mxlogger_riverpod.dart';
import '../../../level/mx_level.dart';
import '../../../theme/mx_theme.dart';


class LogAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget{
  const LogAppBar({Key? key}) : super(key: key);
  @override
  // TODO: implement preferredSize
  Size get preferredSize => const Size.fromHeight(80);
  @override
  LogAppBarState createState() => LogAppBarState();
}

class LogAppBarState extends ConsumerState<LogAppBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10, left: 10),
        child: Column(
          children: [_search(), _level()],
        ));
  }

  Widget _level() {
    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: MXLevels.map((e) {
          return _button(e["number"], e["level"], e["color"]);
        }).toList(),
      ),
    );
  }

  Widget _button(int number, String text, Color textColor) {
    return GestureDetector(
      onTap: () {
        // context.read<RequestController>().updateLevels(number);
      },
      child: Builder(
        builder: (context) {
          //  context.select<RequestController,int>((value) => value.searchLevels.length);
          // Color color =  context.read<RequestController>().containsLevel(number) == true ? MXTheme.buttonColor : Colors.transparent;
          //
          return Container(
            padding: const EdgeInsets.only(left: 7, right: 7),
            margin: EdgeInsets.only(right: 10, top: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: MXTheme.buttonColor,
            ),
            child: Text(text, style: TextStyle(color: textColor, fontSize: 15)),
          );
        },
      ),
    );
  }

  Widget _search() {
    return KeyboardListener(
        onKeyEvent: (event) {
          if (event.physicalKey.usbHidUsage == 0x0007002b) {
            // textFieldController.focusNode.requestFocus();
          }
        },
        focusNode: FocusNode(),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: MXTheme.themeColor,
              borderRadius: BorderRadius.all(Radius.circular(5))),
          height: 30,
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.search, size: 20, color: MXTheme.subText),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                autofocus: true,
                // focusNode: context.read<MXTextFieldController>().focusNode,
                // controller: context.read<MXTextFieldController>().searchController,
                style: TextStyle(fontSize: 16, color: MXTheme.white),

                onSubmitted: (String? keyword) {
                  ref.read(searchKeywordProvider.notifier).state = keyword;

                },

                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: "搜索关键词 回车确定",
                  hintStyle: TextStyle(color: MXTheme.text, fontSize: 16),
                  border: InputBorder.none,
                ),
              ))
            ],
          ),
        ));
  }
}
