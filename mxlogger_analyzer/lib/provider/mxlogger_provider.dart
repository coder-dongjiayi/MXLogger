

import 'package:flutter/cupertino.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

import '../storage/mxlogger_storage.dart';

/// 保存弹框提示的状态
final cryptAlertProvider = StateProvider<bool?>((ref) {
  ref.listenSelf((previous, next) {
    /// 更新本地存储状态
    MXLoggerStorage.instance.saveCryptAlert(next);
  });
  return MXLoggerStorage.instance.cryptAlert;
});

final pageControllerProvider = Provider((ref) {
  return PageController(initialPage: 0);
});

/// 首页选择index
final selectedIndexProvider = StateProvider((ref) {
  PageController controller = ref.read(pageControllerProvider);
  ref.listenSelf((previous, next) {
    if (previous != null) {
        int _next = next as int;
       controller.jumpToPage(_next);
    }
  });
  return 0;
});