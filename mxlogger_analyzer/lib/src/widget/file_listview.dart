import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/theme/mx_theme.dart';

typedef FileItemTapCallback = void Function(String fileName, int size);



class FileListView extends StatefulWidget {
  const FileListView(
      {Key? key, required this.dirPath, this.callback})
      : super(key: key);

  final String dirPath;
  final FileItemTapCallback? callback;

  @override
  _FileListViewState createState() => _FileListViewState();
}

class _FileListViewState extends State<FileListView> {
  int _totalSize = 0;
  Future<List<Map<String, dynamic>>>? _future;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _future = requestData();
  }

  Future<List<Map<String, dynamic>>> requestData() {
    var completer = Completer<List<Map<String, dynamic>>>();
    int totalSize = 0;
    Future(() async {
      List<Map<String, dynamic>> _dataSource = [];
      Directory directory = Directory(widget.dirPath);
      List<FileSystemEntity> fileList = await directory.list().toList();

      for (var element in fileList) {
        Map<String, dynamic> _map = {};
        FileStat state = element.statSync();
        _map["time"] = state.changed;
        _map["size"] = state.size;
        _map["name"] = element.path.split("/").last;
        totalSize = totalSize + state.size;
        _dataSource.add(_map);
      }
      _totalSize = totalSize;
      _dataSource.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
        DateTime t1 = a["time"];
        DateTime t2 = b["time"];

        return t2.compareTo(t1);
      });
      return _dataSource;
    }).then((value) {
      completer.complete(value);
    });

    return completer.future;
  }

  Widget _header() {
    return Container(

      margin: EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
               Text("MXAnalyzer", style: TextStyle(fontSize: 14,color: MXTheme.white)),
              const SizedBox(
                width: 10,
              ),
              Text(_kbString(_totalSize), style: TextStyle(fontSize: 13, color: MXTheme.text))
            ],
          ),
          GestureDetector(
            onTap: () {
              _future = requestData();
              setState(() {});
            },
            child: Icon(
              Icons.refresh,
              color: MXTheme.info,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            List<Map<String, dynamic>> dataSource = snapshot.data ?? [];
            return Stack(
              children: [
                 Positioned(
                   top: 0,
                     left: 0,
                     right: 0,
                     height: 60,
                     child: _header()),
                Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ListView.builder(
                        itemCount: dataSource.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> map = dataSource[index];
                          String name = map["name"];
                          DateTime dateTime = map["time"];
                          int size = map["size"];
                          return GestureDetector(
                              onTap: () {
                                widget.callback?.call(name, size);
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 10, 10, 10),
                                color: index % 2 == 0
                                    ? MXTheme.themeColor
                                    : MXTheme.itemBackground,
                                child: _itemBuiler(
                                    name, dateTime.toString(), _kbString(size)),
                              ));
                        }))
              ],
            );
          } else {
            return SizedBox();
          }
        });
  }

  String _kbString(int size) {
    if (size < 1024) {
      return "$size B";
    }
    double M = 1024.0 * 1024;

    if (size > 1024 && size < M) {
      double sizeK = size / 1024.0;
      return sizeK.toStringAsFixed(2) + "K";
    }

    double G = M * 1024.0;
    if (size > M && size < G) {
      double sizeM = size / M;
      return sizeM.toStringAsFixed(2) + "M";
    }
    if (size > G) {
      double sizeG = size / G;
      return sizeG.toStringAsFixed(2) + "G";
    }
    return "$size Byte";
  }

  Widget _itemBuiler(String name, String time, String kb) {
    return Row(
      children: [
        Icon(Icons.insert_drive_file_outlined, size: 25, color: MXTheme.white),
        const SizedBox(width: 20),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$name", style: TextStyle(color: MXTheme.white, fontSize: 17)),
            const SizedBox(height: 10),
            Text(
              "last time:$time",
              style: TextStyle(color: MXTheme.text, fontSize: 12),
            )
          ],
        )),
        Text("$kb", style: TextStyle(color: MXTheme.text))
      ],
    );
  }
}
