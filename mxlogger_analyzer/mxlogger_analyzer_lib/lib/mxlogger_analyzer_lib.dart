library mxlogger_analyzer_lib;

import 'package:mxlogger_analyzer_lib/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer_lib/src/storage/mxlogger_storage.dart';
export 'package:flutter_easyloading/flutter_easyloading.dart';
export 'package:riverpod/riverpod.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:mxlogger_analyzer_lib/src/page/lis_page/view/crypt_dialog.dart';
export 'package:mxlogger_analyzer_lib/src/provider/mxlogger_repository.dart';
export 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
export 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';
export 'package:mxlogger_analyzer_lib/src/storage/mxlogger_storage.dart';
export 'package:mxlogger_analyzer_lib/src/page/lis_page/log_list_page.dart';
export 'package:mxlogger_analyzer_lib/src/page/error_page/error_page.dart';
export 'package:mxlogger_analyzer_lib/src/page/detail_page/mxlogger_detail_page.dart';
export 'package:mxlogger_analyzer_lib/src/page/setting/setting_page.dart';
Future<void> MXAnalyzerLib_initialize() async{
  await MXLoggerStorage.instance.initialize();
  await AnalyzerDatabase.initDataBase(MXLoggerStorage.instance.databasePath);
}