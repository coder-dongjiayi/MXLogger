import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/json_tree.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';

/// 单条日志对应的 Header（写入端环境信息）弹窗。
/// 多个 .mx 文件各有 header，故按每条日志的 fileHeader 单独查看。
/// 标量字段走紧凑网格，嵌套对象/数组整行 JSON 树。
Future<void> showLogHeaderDialog(BuildContext context, {required LogModel log}) {
  final MXTokens tokens = MXTokens.of(context);
  final Map<String, Object?> header = HeaderInfo.parseHeader(log.fileHeader);
  // Dialog 内部会清掉 MediaQuery padding，安全区在弹出前从宿主 context 取
  final EdgeInsets safeInsets = MediaQuery.viewPaddingOf(context);
  return showDialog<void>(
    context: context,
    barrierColor: tokens.mask,
    // 就近 Navigator：嵌入模式下主题 / l10n 在弹窗内的嵌套 MaterialApp 里
    useRootNavigator: false,
    // 移动端弹窗铺满整屏（底色盖到刘海下），安全区由弹窗内部留白避让
    useSafeArea: !context.isMobileLayout,
    builder: (BuildContext context) =>
        _HeaderDialog(header: header, safeInsets: safeInsets),
  );
}

class _HeaderDialog extends StatelessWidget {
  const _HeaderDialog({required this.header, required this.safeInsets});

  final Map<String, Object?> header;

  /// 宿主屏幕安全区（移动端弹窗铺满时用于避让状态栏 / home indicator）
  final EdgeInsets safeInsets;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    final List<String> scalarKeys = header.keys
        .where((String key) => header[key] is! Map && header[key] is! List)
        .toList();
    final List<String> nestedKeys = header.keys
        .where((String key) => header[key] is Map || header[key] is List)
        .toList();
    // 移动端铺满整屏（设计稿 720px 断点：宽高 100%、无圆角、无左右描边）
    final bool mobile = context.isMobileLayout;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: mobile ? EdgeInsets.zero : const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mobile ? double.infinity : 760),
        child: Container(
          padding: EdgeInsets.only(
            top: mobile ? safeInsets.top : 0,
            bottom: mobile ? safeInsets.bottom : 0,
          ),
          decoration: BoxDecoration(
            color: tokens.panel,
            borderRadius: mobile ? BorderRadius.zero : BorderRadius.circular(14),
            border: mobile ? null : Border.all(color: tokens.border),
            boxShadow: const [
              BoxShadow(color: Color(0x99000000), offset: Offset(0, 24), blurRadius: 70),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: tokens.accent),
                    const SizedBox(width: 9),
                    Text(
                      context.l10n.headerTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.text,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens.panel2,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: tokens.border),
                      ),
                      child: Text(
                        context.l10n.headerItems(header.length),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                          fontFamilyFallback: MXTheme.monoFontFallback,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (header.isNotEmpty) _CopyHeaderButton(header: header),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 16, color: tokens.muted),
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: tokens.border),
              if (header.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      context.l10n.headerEmpty,
                      style: TextStyle(fontSize: 13, color: tokens.faint),
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _scalarGrid(context, tokens, scalarKeys),
                        for (final String key in nestedKeys)
                          _nestedRow(context, tokens, key, header[key]),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 标量字段紧凑网格：桌面自适应列宽 230+，移动端 150+，超窄屏单列
  /// （设计稿 hdr-grid 在 720 / 480 两级断点收窄）
  Widget _scalarGrid(BuildContext context, MXTokens tokens, List<String> keys) {
    if (keys.isEmpty) return const SizedBox.shrink();
    final double minCellWidth = context.isMobileLayout ? 150 : 230;
    final int maxColumns = context.isNarrowLayout ? 1 : 6;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns =
            (constraints.maxWidth / minCellWidth).floor().clamp(1, maxColumns);
        final List<Widget> rows = [];
        for (int i = 0; i < keys.length; i += columns) {
          // 纵向滚动容器内高度无界，用 IntrinsicHeight 让 stretch 有界（单元格等高）
          rows.add(IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int j = 0; j < columns; j++)
                  Expanded(
                    child: i + j < keys.length
                        ? _scalarCell(tokens, keys[i + j], "${header[keys[i + j]]}")
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
      },
    );
  }

  Widget _scalarCell(MXTokens tokens, String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tokens.border, width: 0.5),
          right: BorderSide(color: tokens.border, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // key 按日志原样显示，不做大小写转换
          Text(
            key,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.5,
              color: tokens.faint,
              fontFamilyFallback: MXTheme.monoFontFallback,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: tokens.text,
              fontFamilyFallback: MXTheme.monoFontFallback,
            ),
          ),
        ],
      ),
    );
  }

  /// 嵌套字段整行：key + 尺寸标注 + JSON 树
  Widget _nestedRow(BuildContext context, MXTokens tokens, String key, Object? value) {
    final int size = value is List ? value.length : (value is Map ? value.length : 0);
    final String sizeLabel =
        value is List ? context.l10n.jsonItems(size) : context.l10n.jsonKeys(size);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // key 按日志原样显示，不做大小写转换
              Text(
                key,
                style: TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.5,
                  color: tokens.faint,
                  fontFamilyFallback: MXTheme.monoFontFallback,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                "($sizeLabel)",
                style: TextStyle(
                  fontSize: 10,
                  color: tokens.faint.withValues(alpha: 0.8),
                  fontFamilyFallback: MXTheme.monoFontFallback,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.border),
            ),
            child: JsonTree(value: value, autoDepth: 1),
          ),
        ],
      ),
    );
  }
}

class _CopyHeaderButton extends StatefulWidget {
  const _CopyHeaderButton({required this.header});

  final Map<String, Object?> header;

  @override
  State<_CopyHeaderButton> createState() => _CopyHeaderButtonState();
}

class _CopyHeaderButtonState extends State<_CopyHeaderButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final MXTokens tokens = MXTokens.of(context);
    return Tooltip(
      message: context.l10n.copyHeaderTip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: () async {
            final String text = widget.header.entries
                .map((MapEntry<String, Object?> e) =>
                    "${e.key}: ${e.value is Map || e.value is List ? jsonEncode(e.value) : e.value}")
                .join("\n");
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) showMXToast(context, context.l10n.headerCopied);
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tokens.panel2,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _hovering ? tokens.faint : tokens.border),
            ),
            child: Icon(
              Icons.copy_outlined,
              size: 13,
              color: _hovering ? tokens.text : tokens.muted,
            ),
          ),
        ),
      ),
    );
  }
}
