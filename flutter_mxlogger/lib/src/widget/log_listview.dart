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

    return ListView.builder(
        controller: _scrollController,
        itemCount: _dataSource!.length,
        physics: AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          Map<String, dynamic> map = _dataSource![index];
          return GestureDetector(
              onTap: () {
                widget.callback?.call(index);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                color: index % 2 == 0
                    ? MXTheme.themeColor
                    : MXTheme.itemBackground,
                child: _item(name: map["name"], msg: map["msg"], level: map["level"]),
              ));
        });
  }

  Widget _item({required String name,required String msg, required int level}) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 15),
          child: Text(
            msg,
            maxLines: 3,
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
                  borderRadius: const BorderRadius.all(Radius.circular(3))),
            ))
      ],
    );
  }


}
