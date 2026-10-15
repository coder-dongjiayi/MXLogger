import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';

/// Run from the shell project: flutter test tool/generate_chrome_icons.dart
/// Reuses the brand vector, rasterizing each size directly for sharp edges.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Generate Chrome toolbar and extension icons', () async {
    final tokens = MXTheme.dark().extension<MXTokens>()!;
    for (final size in [16, 32, 48, 128]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // The frame including its stroke fills 94% of the available canvas.
      final paintSize = size * .94 * 48 / 44;
      final origin = (size - paintSize) / 2;
      canvas.translate(origin, origin);
      MXLogoPainter(
        tokens,
        toolbar: true,
      ).paint(canvas, Size.square(paintSize));
      final picture = recorder.endRecording();
      final image = await picture.toImage(size, size);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'chrome_extension/web/icons/$size.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      if (size == 32)
        await File(
          'chrome_extension/web/favicon.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    }
  });
}
