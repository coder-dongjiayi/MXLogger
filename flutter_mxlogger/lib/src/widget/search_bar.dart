import 'package:flutter/material.dart';

import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
import 'package:flutter_mxlogger/src/level/mx_level.dart';

class SearchBar extends StatefulWidget {
  const SearchBar({Key? key}) : super(key: key);

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {

  @override
  Widget build(BuildContext context) {
    return Container(
      child:Column(
        children: [
          _search(),
          _level()
        ],
      ),

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
          const Icon(Icons.search,size: 20),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            style: TextStyle(
              color: MXTheme.white
            ),

            decoration: InputDecoration(
              isCollapsed: true,
              hintText: "搜索关键词",
              hintStyle: TextStyle(color: MXTheme.text),
              border: InputBorder.none,
            ),
          ))
        ],
      ),
    );
  }
}
