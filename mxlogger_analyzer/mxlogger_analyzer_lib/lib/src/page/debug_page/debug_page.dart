import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/home_screen.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/search_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screen/home_screen/widget/home_log_list_view.dart';

import 'dart:io';

import '../../provider/mxlogger_provider.dart';
import 'debug_drawer.dart';

final packageLoadStateProvider =
    StateProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return null;
});

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
        ref.invalidate(mxLogDataSourceProvider);
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
      endDrawer: const DebugDrawer(),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              showSearchDialog(context,
                  margin: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.3),
                  onCondition: (result) {
                ref
                    .read(mxLogDataSourceProvider.notifier)
                    .search(searchState: result.key, value: result.value);
              });
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: MXTheme.dropTargetColor,
                  borderRadius: BorderRadius.circular(25)),
              child: Icon(
                Icons.search_sharp,
                color: MXTheme.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              _refresh();
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: MXTheme.dropTargetColor,
                  borderRadius: BorderRadius.circular(25)),
              child: Icon(
                Icons.refresh,
                color: MXTheme.white,
                size: 30,
              ),
            ),
          )
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).requestFocus(FocusNode());
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            HomeScreen(
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
      ),
    );
  }

  void _refresh() {
    ref.read(mxloggerRepository).deleteData();
    _loadData();
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
