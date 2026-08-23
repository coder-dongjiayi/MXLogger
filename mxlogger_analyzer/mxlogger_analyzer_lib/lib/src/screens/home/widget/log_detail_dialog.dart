import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_share.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/level_badge.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/log_card.dart';

/// 全屏查看单条日志（对齐设计稿 modal）：等级色顶边 + 字段表 + 完整正文。
/// Esc / 点击遮罩关闭。
Future<void> showLogDetailDialog(BuildContext context, {required LogModel log}) {
  final MXTokens tokens = MXTokens.of(context);
  // Dialog 内部会清掉 MediaQuery padding，安全区在弹出前从宿主 context 取
  final EdgeInsets safeInsets = MediaQuery.viewPaddingOf(context);
  return showDialog<void>(
    context: context,
    barrierColor: tokens.mask,
    // 必须用就近 Navigator：嵌入模式下 MXScope / 主题 / l10n 都在弹窗内的
    // 嵌套 MaterialApp 里，走宿主 root navigator 会脱离分析器组件树
    useRootNavigator: false,
    // 移动端弹窗铺满整屏（底色盖到刘海下），安全区由弹窗内部留白避让
    useSafeArea: !context.isMobileLayout,
    builder: (BuildContext context) =>
        _LogDetailDialog(log: log, safeInsets: safeInsets),
  );
}

class _LogDetailDialog extends MXConsumerWidget {
  const _LogDetailDialog({required this.log, required this.safeInsets});

  final LogModel log;

  /// 宿主屏幕安全区（移动端弹窗铺满时用于避让状态栏 / home indicator）
  final EdgeInsets safeInsets;

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final Color levelColor = tokens.levelColor(log.level);
    final MxTimeParts time = log.timeParts;
    final bool isJson = mxTryParseJson(log.msg) != null;
    // 移动端铺满整屏（设计稿 720px 断点：宽高 100%、无圆角、无左右描边）
    final bool mobile = context.isMobileLayout;

    final TextStyle labelStyle = TextStyle(fontSize: 12.5, color: tokens.faint);
    final TextStyle valueStyle = TextStyle(
      fontSize: 12.5,
      color: tokens.text,
      fontFamilyFallback: MXTheme.monoFontFallback,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 880),
        // 圆角容器内嵌顶部等级色条（非均匀 Border 不能与圆角共存）
        child: Container(
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: mobile ? BorderRadius.zero : BorderRadius.circular(14),
            border: mobile ? null : Border.all(color: tokens.border),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 24), blurRadius: 70),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsets.only(top: mobile ? safeInsets.top : 0),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: levelColor, width: 3)),
            ),
            child: Column(
            mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                child: Row(
                  children: [
                    LevelBadge(level: log.level),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: "${time.date} ${time.time}"),
                          TextSpan(text: ".${time.ms}", style: TextStyle(color: tokens.faint)),
                        ]),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: tokens.muted,
                          fontFamilyFallback: MXTheme.monoFontFallback,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 16, color: tokens.muted),
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
              Divider(color: tokens.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 14),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: tokens.border, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _fieldRow(context.l10n.fieldName, "@${log.name ?? "-"}",
                                labelStyle, valueStyle),
                            _fieldRow(
                                context.l10n.fieldTags,
                                log.tags.map((String t) => "#$t").join("  "),
                                labelStyle,
                                valueStyle),
                            _fieldRow(context.l10n.fieldTime, time.full, labelStyle, valueStyle),
                            _fieldRow(
                                context.l10n.fieldKind,
                                isJson ? context.l10n.kindJson : context.l10n.kindText,
                                labelStyle,
                                valueStyle),
                          ],
                        ),
                      ),
                      LogBody(log: log, query: "", fullExpand: true),
                    ],
                  ),
                ),
              ),
              Divider(color: tokens.border),
              Padding(
                // 移动端底栏避让 home indicator（设计稿 modal-foot）
                padding: EdgeInsets.fromLTRB(
                    18, 10, 18, 10 + (mobile ? safeInsets.bottom : 0)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 移动端三个按钮等宽平分整行，便于单手点击（设计稿 modal-foot button flex:1）
                    _FooterButton(
                      label: context.l10n.share,
                      expand: mobile,
                      onTap: () => mxShare(
                        context,
                        title: context.l10n.shareExportTitle,
                        text: log.toShareText(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FooterButton(
                      label: context.l10n.copyLog,
                      expand: mobile,
                      onTap: () => copyLog(context, ref.store, log),
                    ),
                    const SizedBox(width: 8),
                    _FooterButton(
                      label: mobile ? context.l10n.close : context.l10n.closeEsc,
                      expand: mobile,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 44, child: Text(label, style: labelStyle)),
          const SizedBox(width: 14),
          Expanded(child: SelectableText(value, style: valueStyle)),
        ],
      ),
    );
  }
}

class _FooterButton extends StatefulWidget {
  const _FooterButton({required this.label, required this.onTap, this.expand = false});

  final String label;
  final VoidCallback onTap;

  /// 移动端等宽平分底栏
  final bool expand;

  @override
  State<_FooterButton> createState() => _FooterButtonState();
}

class _FooterButtonState extends State<_FooterButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: widget.expand ? 11 : 7),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovering ? tokens.faint : tokens.border),
          ),
          alignment: widget.expand ? Alignment.center : null,
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
    return widget.expand ? Expanded(child: button) : button;
  }
}
