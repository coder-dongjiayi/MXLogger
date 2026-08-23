import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_filter_state.dart';

/// 时间范围面板（对齐设计稿）：从/到 两个时间输入 + 应用/清除。
/// 桌面端用文本输入（yyyy-MM-dd HH:mm:ss），解析失败标红。
class TimePanel extends MXConsumerStatefulWidget {
  const TimePanel({super.key});

  @override
  TimePanelState createState() => TimePanelState();
}

class TimePanelState extends MXConsumerState<TimePanel> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  bool _fromInvalid = false;
  bool _toInvalid = false;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// 支持 "yyyy-MM-dd HH:mm:ss" / "yyyy-MM-dd HH:mm" / "yyyy-MM-dd"
  int? _parseUs(String input) {
    final String text = input.trim();
    if (text.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(text.replaceFirst(" ", "T"));
    return parsed?.microsecondsSinceEpoch;
  }

  void _apply() {
    final String fromText = _fromController.text.trim();
    final String toText = _toController.text.trim();
    final int? fromUs = _parseUs(fromText);
    final int? toUs = _parseUs(toText);
    setState(() {
      _fromInvalid = fromText.isNotEmpty && fromUs == null;
      _toInvalid = toText.isNotEmpty && toUs == null;
    });
    if (_fromInvalid || _toInvalid) return;
    store.filter.update(
        (LogFilterState state) => state.copyWith(fromUs: fromUs, toUs: toUs));
  }

  void _clear() {
    _fromController.clear();
    _toController.clear();
    setState(() {
      _fromInvalid = false;
      _toInvalid = false;
    });
    store.filter
        .update((LogFilterState state) => state.copyWith(fromUs: null, toUs: null));
  }

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final bool mobile = context.isMobileLayout;

    final Widget applyButton = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _apply,
        child: Text(
          context.l10n.apply,
          style: TextStyle(fontSize: 12.5, color: tokens.accent),
        ),
      ),
    );
    final Widget clearButton = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _clear,
        child: Text(
          context.l10n.clear,
          style: TextStyle(fontSize: 12.5, color: tokens.muted),
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.mxPadX, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.panel,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      // 移动端两个时间输入各占一行、铺满宽度（设计稿 stack-mobile），
      // 定宽 190 的输入框在手机上会连同标签一起溢出
      child: mobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(tokens, context.l10n.timeFrom, _fromController, _fromInvalid,
                    expand: true),
                const SizedBox(height: 8),
                _field(tokens, context.l10n.timeTo, _toController, _toInvalid,
                    expand: true),
                const SizedBox(height: 10),
                Row(
                  children: [
                    applyButton,
                    const SizedBox(width: 16),
                    clearButton,
                  ],
                ),
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _field(tokens, context.l10n.timeFrom, _fromController, _fromInvalid),
                _field(tokens, context.l10n.timeTo, _toController, _toInvalid),
                applyButton,
                clearButton,
              ],
            ),
    );
  }

  Widget _field(
    MXTokens tokens,
    String label,
    TextEditingController controller,
    bool invalid, {
    bool expand = false,
  }) {
    final double fontSize = context.mxInputFontSize(12.5);
    final Widget input = Container(
      width: expand ? null : 190,
      decoration: BoxDecoration(
        color: tokens.bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: invalid ? tokens.lvError : tokens.border),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: (_) => _apply(),
        style: TextStyle(
          fontSize: fontSize,
          color: tokens.text,
          fontFamilyFallback: MXTheme.monoFontFallback,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: context.l10n.timeInputHint,
          hintStyle: TextStyle(fontSize: fontSize, color: tokens.faint.withValues(alpha: 0.7)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        ),
      ),
    );

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: tokens.muted)),
        const SizedBox(width: 6),
        if (expand) Expanded(child: input) else input,
      ],
    );
  }
}
