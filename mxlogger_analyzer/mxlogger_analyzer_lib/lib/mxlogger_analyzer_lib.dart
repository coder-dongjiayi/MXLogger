library mxlogger_analyzer_lib;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/src/analyzer_data/analyzer_database.dart';

import 'mxlogger_analyzer_lib.dart';
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
export 'package:mxlogger_analyzer_lib/src/page/debug_page/debug_page.dart';
export 'package:mxlogger_analyzer_lib/src/mxdebug_page.dart';

class MXAnalyzer {
  static OverlayEntry? _analyzerOverlayEntry;

  static bool _visible = true;

  static double _size = 80;
  static double _radius = _size / 2.0;
  static late Offset offset;

  static void initialize({required String databasePath}) {
    AnalyzerDatabase.initDataBase(databasePath);
  }

  static void dismiss() {
    _analyzerOverlayEntry?.remove();
    _analyzerOverlayEntry = null;
  }

  static Future<void> _showModalBottomSheet(BuildContext context,
      {required String diskcachePath,
      required String databasePath,
      String? cryptKey,
      String? iv}) async {
    AnalyzerDatabase.initDataBase(databasePath);

    await showModalBottomSheet(
        context: context,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: MXTheme.themeColor,
        builder: (context) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: MXDebugPage(
              databasePath: databasePath,
              diskcachePath: diskcachePath,
              cryptKey: cryptKey,
              iv: iv,
            ),
          );
        });
    AnalyzerDatabase.db.dispose();
  }

  static void showDebug(OverlayState overlayState,
      {required String diskcachePath,
      required String databasePath,
      bool isDebugMode = kDebugMode,
      String? cryptKey,
      String? iv}) {

    if (_analyzerOverlayEntry != null || isDebugMode == false) return;
    double screenWidth = MediaQuery.of(overlayState.context).size.width;
    double screenHeight = MediaQuery.of(overlayState.context).size.height;

    offset = Offset((screenWidth - _size) / 2.0, (screenHeight - _size) / 2.0);

    _analyzerOverlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: GestureDetector(
            onPanUpdate: (DragUpdateDetails details) {
              if (details.globalPosition.dx - _radius > 0 &&
                  details.globalPosition.dy + _radius < screenHeight &&
                  details.globalPosition.dx + _radius < screenWidth &&
                  details.globalPosition.dy -_radius > 0
              ) {
                offset += details.delta;
                _analyzerOverlayEntry?.markNeedsBuild();
              }
            },
            onTap: () async {
              _visible = false;
              _analyzerOverlayEntry?.markNeedsBuild();
              await _showModalBottomSheet(context,
                  diskcachePath: diskcachePath,
                  databasePath: databasePath,
                  cryptKey: cryptKey,
                  iv: iv);
              _visible = true;
              _analyzerOverlayEntry?.markNeedsBuild();
            },
            child: Visibility(
              visible: _visible,
              child: Container(
                  decoration: BoxDecoration(
                      color: MXTheme.themeColor,
                      borderRadius: BorderRadius.circular(_size / 2.0)),
                  child: Image.asset(
                    "assets/images/logo.png",
                    width: _size,
                    height: _size,
                    package: "mxlogger_analyzer_lib",
                  )),
            ),
          ));
    });
    overlayState.insert(_analyzerOverlayEntry!);
  }
}
