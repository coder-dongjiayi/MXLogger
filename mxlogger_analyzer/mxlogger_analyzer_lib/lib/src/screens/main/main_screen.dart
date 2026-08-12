import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/screen_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_screen.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/import_state.dart';
import 'package:mxlogger_analyzer_lib/src/screens/landing/landing_screen.dart';

/// 主壳：按 [ScreenStore] 在落地页与数据页之间切换，
/// 并统一消费导入结果（失败 toast / 重解析成功 toast）。
class MainScreen extends MXConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends MXConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    ref.listen(store.importer, _onImportChanged);
  }

  void _onImportChanged(ImportState previous, ImportState next) {
    if (!mounted || previous.status == next.status) return;
    if (next.status == ImportStatus.failure) {
      final String message;
      if (next.reparse) {
        message = context.l10n.reparseFailed;
      } else if (next.error == ImportError.readFailed) {
        message = context.l10n.fileReadFailed;
      } else {
        message = context.l10n.parseFailed;
      }
      showMXToast(context, message);
      store.importer.reset();
    } else if (next.status == ImportStatus.success) {
      if (next.reparse) showMXToast(context, context.l10n.reparsedWithNewKey);
      // 首次向导导入成功：记录进入标记并切到数据页
      if (store.screen.value == MxScreen.landing) store.screen.enter();
      // 等切页帧渲染完成后再复位，避免落地页向导在卸载前闪回第一步
      WidgetsBinding.instance.addPostFrameCallback((_) {
        store.importer.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final MxScreen screen = ref.watch(store.screen);
    return Scaffold(
      // 顶部避让状态栏/刘海（嵌入弹窗时上方 padding 已被移除，此处为 0）；
      // 底部不整体避让，由列表留白与悬浮按钮各自处理，避免出现空白条
      body: SafeArea(
        bottom: false,
        child: switch (screen) {
          MxScreen.landing => const LandingScreen(),
          MxScreen.data => const HomeScreen(),
        },
      ),
    );
  }
}
