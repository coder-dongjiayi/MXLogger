library mxlogger_analyzer_lib;

import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/src/analyzer_data/analyzer_database.dart';

import 'mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/page/debug_page/debug_page.dart';
export 'package:riverpod/riverpod.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:mxlogger_analyzer_lib/src/provider/mxlogger_repository.dart';
export 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';
export 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

export 'package:mxlogger_analyzer_lib/src/page/lis_page/log_list_page.dart';
export 'package:mxlogger_analyzer_lib/src/page/error_page/error_page.dart';
export 'package:mxlogger_analyzer_lib/src/page/detail_page/mxlogger_detail_page.dart';
export 'package:mxlogger_analyzer_lib/src/component/mxlogger_text.dart';
export 'package:mxlogger_analyzer_lib/src/component/mxlogger_button.dart';
export 'package:mxlogger_analyzer_lib/src/component/mxlogger_textfield.dart';

void MXAnalyzerLib_init({required String databasePath}){
  AnalyzerDatabase.initDataBase(databasePath);
}

void MXAnalyzerLib_showDebug(BuildContext context,{required String diskcachePath, required String databasePath,String? cryptKey,String? iv}) async{
  AnalyzerDatabase.initDataBase(databasePath);
  showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MXTheme.themeColor,

      builder: (context) {
       return ProviderScope(child: SizedBox(
         height: MediaQuery.of(context).size.height * 0.7,

         child:Container(

           child: DebugPage(
             databasePath: databasePath,
             diskcachePath: diskcachePath,
             cryptKey: cryptKey,
             iv: iv,
           ),
         ),
       ));

      });
}
