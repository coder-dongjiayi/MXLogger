import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:mxlogger_analyzer/page/desktop/desktop_page.dart';
import 'package:mxlogger_analyzer/page/view/crypt_dialog.dart';
import 'package:mxlogger_analyzer/storage/mxlogger_storage.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await   MXLoggerStorage.instance.initialize();
  MXAnalyzer.initialize(databasePath: MXLoggerStorage.instance.databasePath);
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
      builder: EasyLoading.init(),
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropTarget(
        onDragEntered: (detail) {
          ref.read(dropTargetProvider.notifier).state = true;
        },
        onDragExited: (detail) {
          ref.read(dropTargetProvider.notifier).state = false;
        },
        onDragDone: (detail) async {
          if (MXLoggerStorage.instance.cryptAlert != true) {
            bool? result = await CryptDialog.show(context);
            ref.read(dropTargetProvider.notifier).state = false;
            if (result != true) return;
          }
          XFile file = detail.files.first;
          _onDragDone(ref, file);
        },
        child: DesktopPage());
  }

  /// 拖拽完成操作
  void _onDragDone(WidgetRef ref, XFile file) async {
    Uint8List bytes = await file.readAsBytes();
    StreamController<Map<String, dynamic>> streamController =
        StreamController();

    ref.read(mxloggerRepository).importBytes(
        binaryData: [bytes],
        databasePath: MXLoggerStorage.instance.databasePath,
        streamController: streamController,
        cryptKey: MXLoggerStorage.instance.cryptKey,
        cryptIv: MXLoggerStorage.instance.cryptIv);

    streamController.stream.listen((event) {
      int status = event["status"];
      String message = event["message"] ?? "";
      switch (status) {
        case 0:
          EasyLoading.show(status: message);
          break;
        case 1:
          double progress = event["progress"];
          EasyLoading.showProgress(progress, status: message);
          break;
        case 2:
          int repeat = event["repeat"];
          if (repeat > 0) {
            Future.delayed(const Duration(seconds: 1), () {
              EasyLoading.showInfo("$repeat条数据已存在,请勿重复导入",
                  duration: const Duration(seconds: 3));
            });
          } else {

            EasyLoading.showSuccess(message);
          }

          streamController.close();

          /// 刷新数据
          ref.invalidate(logPagesProvider);
          break;
        case 3:
          EasyLoading.showInfo(message);
          ref.invalidate(logPagesProvider);
          break;
        case 4:
          ref.read(errorProvider).add(message);
          ref.read(errorListProvider.notifier).state =
              List.of(ref.read(errorProvider)).toList();
          break;
      }
    });
  }
}
