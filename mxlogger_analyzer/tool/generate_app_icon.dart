import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';

/// 复用 [MXLogoPainter]（深色主题 tokens）生成 macOS AppIcon：
///
/// ```bash
/// flutter test tool/generate_app_icon.dart
/// ```
///
/// 需要 dart:ui 光栅化能力，因此通过 flutter test 运行（不放 test/ 目录，
/// 避免常规测试跑动时重写图标）。每档尺寸按矢量直绘而非位图缩放，
/// 小尺寸下边缘更锐利。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("生成 macOS AppIcon 各尺寸 PNG", () async {
    final MXTokens tokens = MXTheme.dark().extension<MXTokens>()!;

    // macOS 图标规范：1024 画布，图形主体占 824，四周留透明边距；
    // MXLogoPainter 视口 48 单位、圆角方框区 3..45（42 单位），
    // 换算出让方框恰好铺满 824 图形区的绘制尺寸与偏移
    const double canvas1x = 1024;
    const double body1x = 824;
    const double paintSize = 48 * body1x / 42;
    const double origin = (canvas1x - paintSize) / 2;

    const List<int> sizes = [16, 32, 64, 128, 256, 512, 1024];
    for (final int size in sizes) {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      canvas.scale(size / canvas1x);
      canvas.translate(origin, origin);
      MXLogoPainter(tokens).paint(canvas, const Size.square(paintSize));

      final ui.Image image = await recorder.endRecording().toImage(size, size);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final File file = File(
          "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png");
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      stdout.writeln("已生成 ${file.path}");
    }
  });
}
