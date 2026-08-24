import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mxlogger_analyzer_lib/src/app/l10n/l10n_extension.dart';
import 'package:mxlogger_analyzer_lib/src/app/theme/mx_theme.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_responsive.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_share.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_collapsible.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_icon_button.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_logo.dart';
import 'package:mxlogger_analyzer_lib/src/global/widget/mx_toast.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/dialog/clear_data_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/dialog/key_iv_dialog.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/home_screen.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/header_info.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/model/log_model.dart';
import 'package:mxlogger_analyzer_lib/src/screens/home/widget/level_filter_bar.dart';

/// 数据页 header（对齐设计稿）：品牌 + 统计 + 操作按钮 +
/// 等级分布条 + 等级筛选 chips + Header 信息卡片。
class DataHeader extends MXConsumerWidget {
  const DataHeader({super.key});

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXTokens tokens = MXTokens.of(context);
    final MXStore store = ref.store;
    final HeaderInfo info = ref.watch(store.headerInfo).valueOrNull ?? const HeaderInfo();
    final bool isDark = ref.watch(store.themeMode) == ThemeMode.dark;

    final double buttonSize = context.mxTopButtonSize;

    return Container(
      // 左右留白由各子项自行控制：移动端等级 chips 需要铺到屏幕边缘横向滚动
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tokens.headerGrad, tokens.bg],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.mxPadX),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _brand(context, tokens)),
                const SizedBox(width: 12),
                // 窄屏放不下时按钮自动换行，不挤压品牌区
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  alignment: WrapAlignment.end,
                  children: [
                    _ShareAllButton(info: info, size: buttonSize),
                    // 嵌入模式日志来源固定为本机目录：给「刷新」重新扫描解析，
                    // 而不是桌面端的「更换文件」
                    if (store.isEmbedded)
                      MXIconButton(
                        tooltip: context.l10n.refreshTip,
                        icon: const Icon(Icons.refresh),
                        size: buttonSize,
                        onTap: () => refreshDeviceLogs(context, store),
                      )
                    else if (store.host.canPickFiles)
                      MXIconButton(
                        tooltip: context.l10n.changeFileTip,
                        icon: const Icon(Icons.drive_folder_upload_outlined),
                        size: buttonSize,
                        onTap: () => pickAndImportLogFiles(context, store),
                      ),
                    // 桌面端：管理解密 KEY / IV（增删 / 勾选 / 排序，应用即重解析）
                    if (!store.isEmbedded)
                      MXIconButton(
                        tooltip: context.l10n.keyIvTip,
                        icon: const Icon(Icons.key_outlined, size: 15),
                        size: buttonSize,
                        onTap: () => showKeyIvDialog(context),
                      ),
                    MXIconButton(
                      tooltip: context.l10n.clearDataTip,
                      icon: const Icon(Icons.delete_outline),
                      size: buttonSize,
                      onTap: () => _confirmClearData(context, store),
                    ),
                    MXIconButton(
                      tooltip: isDark ? context.l10n.themeToLight : context.l10n.themeToDark,
                      icon: Icon(
                          isDark ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
                          size: 15),
                      size: buttonSize,
                      onTap: store.themeMode.toggle,
                    ),
                    MXIconButton(
                      tooltip: context.l10n.languageTip,
                      icon: const Icon(Icons.translate, size: 15),
                      size: buttonSize,
                      onTap: store.locale.toggle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 手机端可由左下角悬浮按钮收起（品牌行与操作按钮始终保留）
          MXCollapsible(
            collapsed: context.isMobileLayout && ref.watch(store.headerCollapsed),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12),
                LevelFilterBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 清除数据：二次确认 → 清库。桌面端回到首次引导页；
  /// 嵌入模式日志来源固定为本机目录，引导页无意义——留在数据页，
  /// 清空后自然落到带「刷新」按钮的空态。
  Future<void> _confirmClearData(BuildContext context, MXStore store) async {
    final bool? confirmed = await showClearDataDialog(context);
    if (confirmed != true || !context.mounted) return;
    await store.importer.clearAll();
    if (!context.mounted) return;
    showMXToast(context, context.l10n.dataCleared);
    if (!store.isEmbedded) store.screen.resetToLanding();
  }

  Widget _brand(BuildContext context, MXTokens tokens) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MXLogo(size: 22),
        const SizedBox(width: 9),
        // 窄屏按钮占位后品牌名可被压缩（宁可省略号也不溢出）
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: "MX", style: TextStyle(color: tokens.accent)),
              const TextSpan(text: "Logger"),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: tokens.text,
            ),
          ),
        ),
        // 副标题移动端隐藏（设计稿 hide-mobile），给操作按钮腾出宽度
        if (!context.isMobileLayout) ...[
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              context.l10n.parserSubtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: tokens.muted),
            ),
          ),
        ],
      ],
    );
  }

}

/// 分享当前筛选结果（header + 日志正文导出为 txt）。
class _ShareAllButton extends MXConsumerWidget {
  const _ShareAllButton({required this.info, required this.size});

  final HeaderInfo info;
  final double size;

  @override
  Widget build(BuildContext context, MXRef ref) {
    final MXStore store = ref.store;
    return MXIconButton(
      tooltip: context.l10n.shareAllTip,
      icon: const Icon(Icons.share_outlined),
      size: size,
      onTap: () async {
        // 列表分页只加载了部分数据，导出需查全量过滤结果
        final List<LogModel> filtered =
            await store.repository.fetchLogs(store.filter.value);
        final bool hasFilter = store.filter.value.hasFilter;
        if (!context.mounted) return;

        final StringBuffer buffer = StringBuffer();
        if (info.header.isNotEmpty) {
          buffer.writeln(context.l10n.shareHeaderSection);
          info.header.forEach((String key, Object? value) {
            buffer
                .writeln("$key: ${value is Map || value is List ? jsonEncode(value) : value}");
          });
          buffer.writeln();
        }
        buffer.writeln(hasFilter
            ? context.l10n.shareBodyFiltered(filtered.length, info.total)
            : context.l10n.shareBodyAll(info.total));
        for (final LogModel log in filtered) {
          buffer.writeln(log.toShareText());
        }

        final String base = info.fileName.isEmpty
            ? "mxlogger"
            : info.fileName.split(" ").first.replaceAll(RegExp(r"\.[^.]+$"), "");
        mxShare(
          context,
          title: context.l10n.shareExportTitle,
          text: buffer.toString(),
          fileName: "${base}_export.txt",
        );
      },
    );
  }
}
