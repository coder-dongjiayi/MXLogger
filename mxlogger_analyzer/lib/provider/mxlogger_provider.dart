

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