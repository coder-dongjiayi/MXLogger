import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// MXLogger 品牌 logo（对齐设计稿 SVG）：圆角方框内 2x2 色块，
/// 右上色块为强调色并延伸一条指向圆点的斜线。
class MXLogo extends StatelessWidget {
  const MXLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return CustomPaint(size: Size.square(size), painter: MXLogoPainter(tokens));
  }
}

/// logo 几何绘制（48 单位视口，方框区 3..45）。
/// 公开供 tool/generate_app_icon.dart 直绘生成 App 图标，保证与页面 logo 完全一致。
class MXLogoPainter extends CustomPainter {
  MXLogoPainter(this.tokens);

  final MXTokens tokens;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 48;

    RRect box(double x, double y, double w, double h, double r) {
      return RRect.fromRectAndRadius(
        Rect.fromLTWH(x * s, y * s, w * s, h * s),
        Radius.circular(r * s),
      );
    }

    canvas.drawRRect(box(3, 3, 42, 42, 11), Paint()..color = tokens.panel2);
    canvas.drawRRect(
      box(3, 3, 42, 42, 11),
      Paint()
        ..color = tokens.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s,
    );

    final Paint faintFill = Paint()..color = tokens.faint.withValues(alpha: 0.45);
    canvas.drawRRect(box(11, 11, 11, 11, 3), faintFill);
    canvas.drawRRect(box(11, 26, 11, 11, 3), faintFill);
    canvas.drawRRect(box(26, 26, 11, 11, 3), faintFill);

    final Paint accentFill = Paint()..color = tokens.accent;
    canvas.drawRRect(box(26, 11, 11, 11, 3), accentFill);
    canvas.drawLine(
      Offset(31.5 * s, 16.5 * s),
      Offset(41 * s, 7 * s),
      Paint()
        ..color = tokens.accent
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(41 * s, 7 * s), 3.2 * s, accentFill);
  }

  @override
  bool shouldRepaint(MXLogoPainter oldDelegate) => oldDelegate.tokens != tokens;
}
