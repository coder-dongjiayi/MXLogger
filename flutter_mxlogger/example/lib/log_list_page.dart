import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({Key? key, required this.dirPath, this.cryptKey, this.iv})
      : super(key: key);

  final String dirPath;
  final String? cryptKey;
  final String? iv;
  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  Future<List<String>> initData() {
    Completer<List<String>> _completer = Completer();

    Future.delayed(Duration(seconds: 2), () {
      String path = widget.dirPath;
      List<Map<String, dynamic>> files =
          MXLogger.selectLogfiles(directory: path);
      String fileName = files.first["name"];
      List<String> list = MXLogger.selectLogMsg(
          diskcacheFilePath: path + "/" + fileName,
          cryptKey: widget.cryptKey,
          iv: widget.iv);
      _completer.complete(list);
    });
    return _completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("查看日志数据"),
        ),
        body: FutureBuilder<List<String>>(
          future: initData(),
          builder:
              (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
            List<String>? _source = snapshot.data;
            if (_source == null) {
              return const Center(
                child: Text("demo演示 如果数据量大，就多等一会儿"),
              );
            }

            return ListView.builder(
                itemCount: _source.length,
                itemBuilder: (context, index) {
                  return Text(_source[index]);
                });
          },
        ));
  }
}
