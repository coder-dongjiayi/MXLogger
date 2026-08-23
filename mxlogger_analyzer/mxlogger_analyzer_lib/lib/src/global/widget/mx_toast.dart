import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';

OverlayEntry? _activeToast;
Timer? _toastTimer;

/// 底部居中胶囊 toast（对齐设计稿），1.6s 自动消失，重复调用直接替换。
void showMXToast(BuildContext context, String message) {
  // 用宿主 root overlay 保证浮在弹窗之上；那里取不到分析器主题，
  // 故在调用点取好色值传进去（嵌入模式下宿主 app 没有 MXTokens）
  final MXTokens tokens = MXTokens.of(context);
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  _toastTimer?.cancel();
  _activeToast?.remove();

  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext context) => _MXToast(message: message, tokens: tokens),
  );
  _activeToast = entry;
  overlay.insert(entry);
  _toastTimer = Timer(const Duration(milliseconds: 1600), () {
    entry.remove();
    if (_activeToast == entry) _activeToast = null;
  });
}

class _MXToast extends StatefulWidget {
  const _MXToast({required this.message, required this.tokens});

  final String message;

  /// 调用点（分析器组件树内）取到的色值
  final MXTokens tokens;

  @override
  State<_MXToast> createState() => _MXToastState();
}

class _MXToastState extends State<_MXToast> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = widget.tokens;
    return Positioned(
      left: 16,
      right: 16,
      // 避让 home indicator，手机上不贴到屏幕最底
      bottom: 24 + MediaQuery.viewPaddingOf(context).bottom,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 0.6),
            duration: const Duration(milliseconds: 200),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: tokens.panel2,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tokens.border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 20),
                  ],
                ),
                child: Text(
                  widget.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: tokens.text,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
