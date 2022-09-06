import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../level/mx_level.dart';
import '../../../theme/mx_theme.dart';
import '../controller/mx_textfield_controller.dart';
import '../controller/request_controller.dart';
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
     padding: EdgeInsets.only(top: 10,left: 10),
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
          return _button(e["number"], e["level"],e["color"]);
        }).toList(),
      ),
    );
  }

  Widget _button(int number, String text,Color textColor){
    return GestureDetector(
      onTap: (){
       context.read<RequestController>().updateLevels(number);
      },
      child: Builder(builder: (context){
        context.select<RequestController,int>((value) => value.searchLevels.length);
       Color color =  context.read<RequestController>().containsLevel(number) == true ? MXTheme.buttonColor : Colors.transparent;
        return Container(
          padding: const EdgeInsets.only(left: 7,right: 7),
          margin: EdgeInsets.only(right: 10,top: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: color,
          ),
          child: Text(text,style: TextStyle(color: textColor,fontSize: 15)),
        );
      },),
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
            autofocus: true,
            focusNode: context.read<MXTextFieldController>().focusNode,
            controller: context.read<MXTextFieldController>().searchController,
            style: TextStyle(
              fontSize: 16,
                color: MXTheme.white
            ),
            onChanged: (value){
              context.read<MXTextFieldController>().searchChange(context, value);
            },

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
