import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/desktop_page.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/view/crypt_dialog.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_provider.dart';
import 'package:mxlogger_analyzer/src/provider/mxlogger_repository.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MXLoggerStorage.instance.initialize();
  await AnalyzerDatabase.initDataBase(MXLoggerStorage.instance.databasePath);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
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
  void _onDragDone(WidgetRef ref, XFile file) {
    ref
        .read(mxloggerRepository)
        .importBinaryData(
            file: file,
            cryptKey: MXLoggerStorage.instance.cryptKey,
            cryptIv: MXLoggerStorage.instance.cryptIv)
        .listen((event) {
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
          EasyLoading.showSuccess(message);
          break;
        case 3:
          EasyLoading.showInfo(message);
          break;
        case 4:
          ref.read(errorProvider).add(message);
          ref.read(errorListProvider.notifier).state = List.of(ref.read(errorProvider)).toList();
          break;
      }

      /// 刷新数据
      ref.invalidate(logPagesProvider);
    });
  }
}
