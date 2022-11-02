import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';

import '../log_model.dart';

typedef LogItemTapCallback = void Function(int index);

class LogListView extends StatefulWidget {
  LogListView({Key? key, required this.dataSource, this.callback})
      : super(key: key);
  List<LogModel> dataSource;
  LogItemTapCallback? callback;

  @override
  _LogListViewState createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {

  @override
  void initState() {

    // TODO: implement initState
    super.initState();

  }

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.only(top: 10),

      child:  ListView.builder(
          itemCount: widget.dataSource.length,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            LogModel log = widget.dataSource[index];
            DateTime time =  DateTime.fromMicrosecondsSinceEpoch(log.timestamp);

            return GestureDetector(
                onTap: () {
                  widget.callback?.call(index);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),

                  color: index %2 == 0 ? MXTheme.themeColor : MXTheme.itemBackground,
                  child: _item(
                      name: log.name ?? "",
                      msg: log.msg ?? "",
                      level: log.level,
                      time: "${time.toString()}",
                      tag: log.tag
                  ),
                ));
          }),
    );
  }

  Widget _item(
      {required String name,
      required String msg,
      required int level,
      required String time,
        String? tag
      }) {

    List<String>? tagList = tag?.split(",");

    return Stack(
      children: [
        Container(
            margin:const EdgeInsets.only(left: 20),
            padding:const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time,
                        style: TextStyle(color: MXTheme.subText, fontSize: 13)),
                    Text("【$name】",style: TextStyle(color: MXTheme.subText, fontSize: 13))
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: List.generate(tagList?.length ?? 0, (index){
                    return _tag(tagList?[index]);
                  }),
                ),
                const SizedBox(height: 5),
                Text(
                  msg,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: MXTheme.text, fontSize: 16),
                ),
              ],
            )),
        Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                  color: MXTheme.colorLevel(level),
                  borderRadius:const BorderRadius.all(Radius.circular(5))),
            )),
        Positioned(
            left: 4,
            top: 10 + 3,
            bottom: 0,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                  color: MXTheme.itemBackground,
                  borderRadius: const BorderRadius.all(Radius.circular(3))),
            ))
      ],
    );
  }
}

Widget _tag(String? tag) {
  if(tag == null || tag == "") return SizedBox();
  return Container(
    decoration: BoxDecoration(
        color: MXTheme.tag, borderRadius: BorderRadius.all(Radius.circular(5))),
    margin: EdgeInsets.only(right: 10),
    padding: EdgeInsets.fromLTRB(5, 2, 5, 4),
    child:
        Text(tag, style: TextStyle(color: MXTheme.text, fontSize: 12)),
  );
}
