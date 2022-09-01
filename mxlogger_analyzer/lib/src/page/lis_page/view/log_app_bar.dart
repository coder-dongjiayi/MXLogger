import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../level/mx_level.dart';
import '../../../theme/mx_theme.dart';
import '../log_controller.dart';
class LogAppBar extends StatefulWidget implements PreferredSizeWidget{
  const LogAppBar({Key? key}) : super(key: key);

  @override
  State<LogAppBar> createState() => _LogAppBarState();

  @override
  // TODO: implement preferredSize
  Size get preferredSize => const Size.fromHeight(80);
}

class _LogAppBarState extends State<LogAppBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
     padding: EdgeInsets.only(top: 10),
      child:  Column(
        children: [
        _search(),
        _level()
    ],
      )
    );
  }
  Widget _level(){
    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection:Axis.horizontal,
        children: MXLevels.map((e){
          return _button(e["level"],e["color"]);
        }).toList(),
      ),
    );
  }

  Widget _button(String text,Color textColor){
    return Container(
      padding: const EdgeInsets.only(left: 10,right: 10,bottom: 5,top: 10),
      child: Column(
        children: [
          Text(text,style: TextStyle(color: textColor,fontSize: 16))
        ],
      ),
    );
  }
  Widget _search(){

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: MXTheme.themeColor,
          borderRadius: BorderRadius.all(Radius.circular(5))
      ),
      height: 30,
      child: Row(
        children:  [
          const SizedBox(width: 10),
           Icon(Icons.search,size: 20,color: MXTheme.subText),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: context.read<LogController>().searchController,
            style: TextStyle(
              fontSize: 16,
                color: MXTheme.white
            ),

            decoration: InputDecoration(
              isCollapsed: true,
              hintText: "搜索关键词 回车确定",
              hintStyle: TextStyle(color: MXTheme.text,fontSize: 16),
              border: InputBorder.none,
            ),
          ))
        ],
      ),
    );
  }
}
