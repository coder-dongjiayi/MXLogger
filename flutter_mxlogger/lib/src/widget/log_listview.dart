import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';
typedef LogItemTapCallback = void Function(int index);
class LogListView extends StatefulWidget {
   LogListView({Key? key,this.dataSource,this.callback}) : super(key: key);
   List<Map<String,dynamic>>? dataSource;
   LogItemTapCallback? callback;
  @override
  _LogListViewState createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  @override
  Widget build(BuildContext context) {
    if(widget.dataSource == null) return const SizedBox();
    return ListView.builder(
        itemCount: widget.dataSource!.length,
        itemBuilder: (context, index) {
          Map<String,dynamic> map =  widget.dataSource![index];
          return GestureDetector(
            onTap: (){
              widget.callback?.call(index);
            },
              child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            color:
            index % 2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,

            child: _item(msg: map["msg"],level: map["level"]),
          ));
        });
  }

  Widget _item({required String msg,required int level}) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Text(
            "这是日志的详细说明信息,苹果支付成功，请前往AppStore后台查看对账单",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: MXTheme.text),
          ),
        ),
        Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: Container(
             decoration: BoxDecoration(
               color: MXTheme.colorLevel(level),
               borderRadius: const BorderRadius.all(Radius.circular(3))
             ),
            ))
      ],
    );
  }


}
