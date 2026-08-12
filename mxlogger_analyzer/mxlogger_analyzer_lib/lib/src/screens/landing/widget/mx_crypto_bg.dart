import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

/// 引导页背景动画（对齐设计稿 mx-bg.js `<mx-crypto-bg>`）：
/// 二进制雨自上而下滚落 + 加解密令牌淡入淡出并周期性乱码翻转。
/// 按 ~30fps 低帧率步进；测试环境与系统「减少动画」时只绘制静态一帧
/// （对齐设计稿 prefers-reduced-motion 行为）。
class MXCryptoBg extends StatefulWidget {
  const MXCryptoBg({super.key});

  @override
  State<MXCryptoBg> createState() => _MXCryptoBgState();
}

class _MXCryptoBgState extends State<MXCryptoBg> with SingleTickerProviderStateMixin {
  static const Duration _step = Duration(microseconds: 33333); // 1/30s

  final _CryptoBgSimulation _sim = _CryptoBgSimulation();
  final _RepaintNotifier _repaint = _RepaintNotifier();
  Ticker? _ticker;
  Duration _previous = Duration.zero;
  Duration _pending = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool static = Platform.environment.containsKey("FLUTTER_TEST") ||
        MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (static) {
      _ticker?.dispose();
      _ticker = null;
    } else {
      _ticker ??= createTicker(_onTick)..start();
    }
  }

  void _onTick(Duration elapsed) {
    _pending += elapsed - _previous;
    _previous = elapsed;
    // 卡顿后最多补 5 步，避免追帧雪崩
    if (_pending > _step * 5) _pending = _step * 5;
    bool advanced = false;
    while (_pending >= _step) {
      _pending -= _step;
      _sim.step(1 / 30);
      advanced = true;
    }
    if (advanced) _repaint.mark();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      size: Size.infinite,
      painter: _CryptoBgPainter(
        simulation: _sim,
        repaint: _repaint,
        // 对齐设计稿 colors()：雨点/令牌复用 accent 与 muted，明暗主题不同透明度
        accent: tokens.accent,
        dim: tokens.muted,
        rainAlpha: isDark ? 0.3 : 0.14,
        headAlpha: isDark ? 0.9 : 0.4,
        tokenAlpha: isDark ? 0.85 : 0.55,
      ),
    );
  }
}

class _RepaintNotifier extends ChangeNotifier {
  void mark() => notifyListeners();
}

/// 一列二进制雨。
class _RainColumn {
  _RainColumn({
    required this.x,
    required this.y,
    required this.speed,
    required this.len,
    required this.seed,
  });

  final double x;
  double y;
  double speed;
  int len;
  final double seed;
}

/// 一条加解密令牌：淡入 → 缓慢上浮 + 周期性乱码翻转 → 淡出重生。
class _Token {
  _Token({
    required this.label,
    required this.x,
    required this.y,
    required this.age,
    required this.life,
    required this.scrambleIn,
    required this.vy,
  }) : display = label;

  final String label;
  String display;
  final double x;
  double y;
  double age;
  final double life;

  /// 距下一次乱码翻转的秒数 / 本次翻转剩余秒数
  double scrambleIn;
  double scrambleLeft = 0;
  final double vy;
}

/// 背景动画状态与步进（对齐 mx-bg.js 的 init/spawn/draw 数值）。
class _CryptoBgSimulation {
  static const String _hex = "0123456789abcdef";
  static const double _cell = 15;
  static const double _colWidth = 26;
  static const List<String> _tokenLabels = [
    "AES-CFB-128", "RSA-2048 ▸ OAEP", "IV ▸ 16 bytes", "KEY ▸ 128 bit",
    "XOR ⊕ block", "mmap ▸ page 0x2F", "cipher ▸ 0x7f3a9c01", "decrypt ▸ ok",
    "SHA-256", "plaintext ▸ log#4821", "Flutter ▸ MethodChannel", "Dart ▸ dart:ffi",
    "Android ▸ JNI bridge", "iOS ▸ objc runtime", "C/C++ ▸ mx_core.cpp",
    "libmxlogger.so", "MXLogger.xcframework", "Kotlin ▸ external fun",
    "Swift ▸ @_cdecl", "NDK ▸ arm64-v8a",
  ];

  final math.Random _random = math.Random();
  final List<_RainColumn> columns = [];
  final List<_Token> tokens = [];
  Size size = Size.zero;
  double t = 0;

  /// 尺寸变化时重建雨列与令牌（对齐 resize→init）
  void ensureSize(Size next) {
    if (next == size || next.isEmpty) return;
    size = next;
    columns.clear();
    final int colCount = (size.width / _colWidth).ceil();
    for (int i = 0; i < colCount; i++) {
      columns.add(_RainColumn(
        x: i * _colWidth + 8,
        y: _random.nextDouble() * size.height * 1.6 - size.height * 0.6,
        speed: 14 + _random.nextDouble() * 34,
        len: 7 + _random.nextInt(13),
        seed: _random.nextDouble() * 100,
      ));
    }
    tokens.clear();
    final int tokenCount = math.max(6, math.min(14, size.width ~/ 130));
    for (int i = 0; i < tokenCount; i++) {
      tokens.add(_spawn(init: true));
    }
  }

  _Token _spawn({required bool init}) {
    return _Token(
      label: _tokenLabels[_random.nextInt(_tokenLabels.length)],
      x: 20 + _random.nextDouble() * math.max(40, size.width - 170),
      y: size.height * 0.06 + _random.nextDouble() * size.height * 0.88,
      age: init ? _random.nextDouble() * 10 : 0,
      life: 13 + _random.nextDouble() * 9,
      scrambleIn: 1.5 + _random.nextDouble() * 5,
      vy: -(3 + _random.nextDouble() * 6) / 60,
    );
  }

  void step(double dt) {
    if (size.isEmpty) return;
    for (final _RainColumn col in columns) {
      col.y += col.speed * dt;
      if (col.y - col.len * _cell > size.height) {
        col.y = -_random.nextDouble() * size.height * 0.4;
        col.speed = 14 + _random.nextDouble() * 34;
        col.len = 7 + _random.nextInt(13);
      }
    }
    for (int i = 0; i < tokens.length; i++) {
      final _Token token = tokens[i];
      token.age += dt;
      token.y += token.vy;
      token.scrambleIn -= dt;
      if (token.age > token.life) {
        tokens[i] = _spawn(init: false);
        continue;
      }
      if (token.scrambleIn <= 0) {
        token.scrambleLeft = 0.9;
        token.scrambleIn = 2.5 + _random.nextDouble() * 5.5;
      }
      if (token.scrambleLeft > 0) {
        token.scrambleLeft -= dt;
        // 加密乱码→解密回落：正弦包络控制翻转概率
        final double wave =
            math.sin((1 - math.max(0, token.scrambleLeft) / 0.9) * math.pi);
        final StringBuffer out = StringBuffer();
        for (final int code in token.label.runes) {
          final String ch = String.fromCharCode(code);
          out.write(ch != " " && _random.nextDouble() < wave * 0.85
              ? _hex[_random.nextInt(16)]
              : ch);
        }
        token.display = out.toString();
      } else {
        token.display = token.label;
      }
    }
    t += dt;
  }
}

class _CryptoBgPainter extends CustomPainter {
  _CryptoBgPainter({
    required this.simulation,
    required this.accent,
    required this.dim,
    required this.rainAlpha,
    required this.headAlpha,
    required this.tokenAlpha,
    super.repaint,
  });

  final _CryptoBgSimulation simulation;
  final Color accent;
  final Color dim;
  final double rainAlpha;
  final double headAlpha;
  final double tokenAlpha;

  /// 雨点字形缓存：字符(0/1) × 头/尾 × 量化透明度，避免每帧上千次 TextPainter 布局
  final Map<int, TextPainter> _glyphCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    simulation.ensureSize(size);

    for (final _RainColumn col in simulation.columns) {
      for (int i = 0; i < col.len; i++) {
        final double y = col.y - i * _CryptoBgSimulation._cell;
        if (y < -_CryptoBgSimulation._cell || y > size.height + _CryptoBgSimulation._cell) {
          continue;
        }
        final double fade = 1 - i / col.len;
        final int char = (math.sin(col.seed + i * 7.13 + (simulation.t * 1.5).floorToDouble())
                    .abs() *
                2)
            .floor()
            .clamp(0, 1);
        final bool head = i == 0;
        final double alpha = (head ? headAlpha : rainAlpha) * fade;
        _rainGlyph(char, head, alpha).paint(canvas, Offset(col.x, y));
      }
    }

    for (final _Token token in simulation.tokens) {
      final double alpha = math.min(
            math.min(1, token.age / 1.2),
            math.min(1, (token.life - token.age) / 2),
          ) *
          tokenAlpha;
      if (alpha <= 0) continue;
      final bool scrambling = token.scrambleLeft > 0;
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: token.display,
          style: TextStyle(
            fontSize: 11.5,
            color: scrambling
                ? accent.withValues(alpha: alpha)
                : dim.withValues(alpha: alpha * 0.75),
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(token.x, token.y));
      painter.dispose();
    }
  }

  TextPainter _rainGlyph(int char, bool head, double alpha) {
    final int step = (alpha * 24).round().clamp(0, 24);
    final int key = (step << 2) | (head ? 2 : 0) | char;
    return _glyphCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: "$char",
          style: TextStyle(
            fontSize: 11,
            color: (head ? accent : dim).withValues(alpha: step / 24),
            fontFamilyFallback: MXTheme.monoFontFallback,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  bool shouldRepaint(_CryptoBgPainter oldDelegate) {
    return oldDelegate.simulation != simulation ||
        oldDelegate.accent != accent ||
        oldDelegate.dim != dim ||
        oldDelegate.rainAlpha != rainAlpha;
  }
}
