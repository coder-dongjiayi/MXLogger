import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

import 'dart:io';

import 'debug_drawer.dart';



class DebugPage extends ConsumerStatefulWidget {
  const DebugPage(
      {Key? key,
      required this.diskcachePath,
      required this.databasePath,
      this.cryptKey,
      this.iv})
      : super(key: key);
  final String diskcachePath;
  final String databasePath;
  final String? cryptKey;
  final String? iv;

  @override
  DebugPageState createState() => DebugPageState();
}

class DebugPageState extends ConsumerState<DebugPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  StreamController<Map<String, dynamic>?> streamController = StreamController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    analyzerPlatform = AnalyzerPlatform.package;
    streamController.stream.listen((event) {
      ref.read(packageLoadStateProvider.notifier).state = event;
      int? status = event?["status"];
      if (status == 2) {
        ref.invalidate(logPagesProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: MXTheme.themeColor,
      endDrawerEnableOpenDragGesture: false,
      drawerScrimColor: Colors.transparent,
      endDrawer: DebugDrawer(
        refreshCallback: () {
          /// 刷新之前先清库
          ref.read(mxloggerRepository).deleteData();
          _loadData();
        },
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          LogListPage(
            menuCallback: () {
              _scaffoldKey.currentState!.openEndDrawer();
            },
            refreshCallback: () {
              _loadData();
            },
          ),
          _loading()
        ],
      ),
    );
  }

  Widget _loading() {
    return Consumer(builder: (context, ref, child) {
      final result = ref.watch(packageLoadStateProvider);
      int? status = result?["status"];
      String message = result?["message"] ?? "";
      if (status == 2 || status == null) return const SizedBox();
      return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.7),
              borderRadius: BorderRadius.circular(10)),
          width: 160,
          height: 160,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(
                color: Colors.white,
                radius: 20,
              ),
              const SizedBox(
                height: 10,
              ),
              MXLoggerText(
                text: message,
                style: TextStyle(color: MXTheme.text),
              )
            ],
          ));
    });
  }

  void _loadData() {
    String diskcachePath = widget.diskcachePath;
    String? cryptKey = widget.cryptKey;
    String? iv = widget.iv;
    Directory directory = Directory(diskcachePath);
    List<FileSystemEntity> fileList = directory.listSync();
    List<Uint8List> bytes = [];
    fileList.forEach((element) {
      Uint8List byte = File(element.path).readAsBytesSync();
      bytes.add(byte);
    });
    ref.read(mxloggerRepository).importBytes(
        binaryData: bytes,
        databasePath: widget.databasePath,
        streamController: streamController,
        cryptIv: iv,
        cryptKey: cryptKey);
  }
}
