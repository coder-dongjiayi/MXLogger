import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/src/theme/mx_theme.dart';

typedef LogItemTapCallback = void Function(int index);

class LogListView extends StatefulWidget {
  LogListView({Key? key, this.dataSource, this.callback, this.loadMoreBack})
      : super(key: key);
  List<Map<String, dynamic>>? dataSource;
  LogItemTapCallback? callback;
  final VoidCallback? loadMoreBack;
  @override
  _LogListViewState createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> {
  late ScrollController _scrollController;
  List<Map<String, dynamic>>? _dataSource;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _scrollController = ScrollController();
    _dataSource = widget.dataSource;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        widget.loadMoreBack?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dataSource == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
          controller: _scrollController,
          itemCount: _dataSource!.length,
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            Map<String, dynamic> map = _dataSource![index];
            String time = map["time"];

            return GestureDetector(
                onTap: () {
                  widget.callback?.call(index);
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),

                  child: _item(
                      name: map["name"],
                      msg: map["msg"],
                      level: map["level"],
                      time: time),
                ));
          }),
    );
  }

  Widget _item(
      {required String name,
      required String msg,
      required int level,
      required String time}) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.only(left: 20),
          padding: EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(time,style: TextStyle(color: MXTheme.subText,fontSize: 13)),
              SizedBox(height: 5),
              Text(
                msg,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: MXTheme.text,fontSize: 16),
              ),
            ],
          )
        ),
        Positioned(
          top: 0,
            left: 0,
            child: Container(
          width: 10,
          height: 10,
          margin: EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
              color: MXTheme.colorLevel(level),
              borderRadius: BorderRadius.all(Radius.circular(5))
          ),
        )),
        Positioned(
            left: 4,
            top: 10+3,
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
