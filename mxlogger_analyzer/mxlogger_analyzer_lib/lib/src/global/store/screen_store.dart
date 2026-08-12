import 'package:mxlogger_analyzer_lib/src/global/host/mx_prefs.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';

/// 当前页面：落地页（首次配置 KEY/IV）/ 数据页（空态支持拖入/选择日志）。
enum MxScreen { landing, data }

const String _enteredKey = "mx_entered";

/// 页面切换：首次使用停留在落地页配置解密参数，之后直接进数据页。
class ScreenStore extends MXState<MxScreen> {
  ScreenStore(MXPrefs prefs)
      : _prefs = prefs,
        super((prefs.getBool(_enteredKey) ?? false) ? MxScreen.data : MxScreen.landing);

  final MXPrefs _prefs;

  /// 落地页「进入解析器」：记录已进入标记
  void enter() {
    _prefs.setBool(_enteredKey, true);
    value = MxScreen.data;
  }

  void show(MxScreen screen) {
    value = screen;
  }

  /// 清空数据后回到首次引导页（清掉进入标记，下次启动也从引导开始）
  void resetToLanding() {
    _prefs.setBool(_enteredKey, false);
    value = MxScreen.landing;
  }
}
