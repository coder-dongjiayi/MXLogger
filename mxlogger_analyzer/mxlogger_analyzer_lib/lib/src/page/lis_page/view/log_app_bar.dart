import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

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
      child: Consumer(builder: (context,ref,_){
      List<LevelModel> levelList = ref.watch(levelSearchProvider);
       return ListView(
          scrollDirection: Axis.horizontal,
          children: List.generate(levelList.length, (index) {
            LevelModel model = levelList[index];
            return _button(model);
          })
        );
      }),
    );
  }

  Widget _button(LevelModel model) {
    return GestureDetector(
      onTap: () {
        ref.read(levelSearchProvider.notifier).selected(level: model.level);
      },
      child: Builder(
        builder: (context) {

        return Container(
            padding: const EdgeInsets.only(left: 7, right: 7),
            margin: EdgeInsets.only(right: 10, top: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: model.selected == true ? MXTheme.buttonColor : Colors.transparent,
            ),
            child: Text(model.levelDesc, style: TextStyle(color: model.color, fontSize: 15)),
          );
        },
      ),
    );
  }

  Widget _search() {
    return Container(
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
                autofocus: false,

                style: TextStyle(fontSize: 16, color: MXTheme.white),
                onChanged: (String? keyword){
                  if(keyword?.isEmpty == true){
                    ref.read(keywordSearchProvider.notifier).state = null;
                  }
                },
                onSubmitted: (String? keyword) {
                  ref.read(keywordSearchProvider.notifier).state = keyword;
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
    );
  }
}
