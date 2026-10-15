import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_app.dart';

import 'package:mxlogger_chrome_prototype/browser_fonts.dart';

String _text(BuildContext context, String zh, String en) =>
    Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

class BrowserFontShell extends StatelessWidget {
  const BrowserFontShell({super.key, required this.fonts, required this.child});
  final BrowserFonts fonts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fonts,
      builder: (context, _) {
        final tokens = MXTokens.of(context);
        final status = fonts.busy
            ? _text(context, '正在安装字体…', 'Installing font…')
            : fonts.hasMissing
            ? _text(
                context,
                '日志有未覆盖的字符，请安装字体或导入本地字体。',
                'Some log characters need a font pack. Install or import a font.',
              )
            : fonts.loaded
            ? _text(context, '日志字体已加载', 'Log fonts loaded')
            : _text(context, '基础界面字体', 'Basic interface fonts');
        return Column(
          children: [
            Expanded(
              child: KeyedSubtree(key: ValueKey(fonts.revision), child: child),
            ),
            Material(
              color: tokens.panel,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: tokens.border)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.text_fields,
                      size: 16,
                      color: fonts.hasMissing ? tokens.lvWarning : tokens.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        container: true,
                        label: status,
                        liveRegion: fonts.hasMissing,
                        excludeSemantics: true,
                        child: Text(
                          status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: tokens.muted),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showFontSettings(context, fonts),
                      child: Text(_text(context, '字体设置', 'Font settings')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showFontSettings(BuildContext context, BrowserFonts fonts) =>
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => _FontDialog(fonts: fonts),
    );

class _FontDialog extends StatelessWidget {
  const _FontDialog({required this.fonts});
  final BrowserFonts fonts;

  String _error(BuildContext context) => switch (fonts.error) {
    'download' => _text(
      context,
      '字体下载源均未能完成下载。可重试，或导入本地字体文件；其他网站能访问不代表这些下载源可访问。',
      'Neither font source completed the download. Retry or import a local font; these sources may be unreachable even when other websites work.',
    ),
    'invalid' => _text(
      context,
      '字体文件无效或校验失败，请选择有效的 WOFF2、TTF 或 OTF 文件。',
      'Invalid font or verification failed. Choose a valid WOFF2, TTF or OTF file.',
    ),
    'cacheSave' => _text(
      context,
      '本地存储操作失败。已加载的字体在当前页面仍可使用。',
      'Local storage failed. Loaded fonts remain available on this page.',
    ),
    'cacheRestore' => _text(
      context,
      '部分字体缓存未能恢复，请重新安装或导入字体。',
      'Some cached fonts could not be restored. Install or import them again.',
    ),
    _ => '',
  };

  String _downloadDetails(BuildContext context) => fonts.downloadAttempts
      .map((attempt) {
        final reason = switch (attempt['code']) {
          'http' => 'HTTP ${attempt['status']}',
          'timeout' => _text(
            context,
            '连接或传输超时',
            'Connection or transfer timed out',
          ),
          'integrity' => _text(context, '文件校验失败', 'File verification failed'),
          'size' => _text(context, '文件超过大小限制', 'File exceeds the size limit'),
          'incomplete' => _text(context, '未收到完整文件', 'Incomplete response'),
          _ => _text(
            context,
            '无法连接（可能被网络、代理或浏览器策略拦截）',
            'Connection failed (network, proxy or browser policy may have blocked it)',
          ),
        };
        return '${fonts.sourceName(attempt['index'] as int)}：$reason';
      })
      .join('\n');

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: fonts,
      builder: (context, _) {
        final tokens = MXTokens.of(context);
        final progress = fonts.downloadBytes == 0
            ? null
            : (fonts.received / fonts.downloadBytes).clamp(0.0, 1.0);
        return Dialog(
          backgroundColor: tokens.panel,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: tokens.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(context, '字体设置', 'Font settings'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: tokens.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _text(
                      context,
                      '界面字体已内置。完整中文和常用日文日志字体按需安装，安装后在此浏览器缓存，下次可离线使用。',
                      'Interface fonts are bundled. Install log fonts for Chinese and common Japanese characters once; cached fonts work offline next time.',
                    ),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.7,
                      color: tokens.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.panel2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(
                            context,
                            fonts.recommendedCjk
                                ? '中文 / 日文日志字体 · 推荐'
                                : '中文 / 日文日志字体',
                            fonts.recommendedCjk
                                ? 'Chinese / Japanese log fonts · Recommended'
                                : 'Chinese / Japanese log fonts',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: tokens.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _text(
                            context,
                            'Google Fonts 字体 · jsDelivr / GitHub 双源 · 下载 ${mxFmtBytes(fonts.downloadBytes)}',
                            'Google Fonts · jsDelivr / GitHub sources · ${mxFmtBytes(fonts.downloadBytes)} download',
                          ),
                          style: TextStyle(fontSize: 11.5, color: tokens.muted),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: fonts.busy ? null : fonts.installOnline,
                          icon: const Icon(Icons.download_outlined, size: 16),
                          label: Text(
                            _text(context, '下载安装字体', 'Download and install'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: fonts.busy ? null : fonts.importFile,
                    icon: const Icon(Icons.folder_open_outlined, size: 16),
                    label: Text(
                      _text(context, '导入本地字体文件', 'Import a local font'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _text(
                      context,
                      '支持 WOFF2 / TTF / OTF，最大 32 MB。字体安装只读取字体文件，日志、KEY 和 IV 不会上传。',
                      'WOFF2 / TTF / OTF, up to 32 MB. Installation only reads font files; logs, KEY and IV are never uploaded.',
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: tokens.muted,
                    ),
                  ),
                  if (fonts.busy) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: fonts.stage == 'download' ? progress : null,
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        fonts.stage == 'download'
                            ? '${fonts.downloadSourceIndex > 0 ? _text(context, '已切换备用源', 'Using fallback source') : _text(context, '正在下载', 'Downloading')} · ${fonts.sourceName(fonts.downloadSourceIndex)}\n${mxFmtBytes(fonts.received)} / ${mxFmtBytes(fonts.downloadBytes)}'
                            : _text(
                                context,
                                '正在校验并安装字体…',
                                'Validating and installing…',
                              ),
                        style: TextStyle(fontSize: 12, color: tokens.muted),
                      ),
                    ),
                    if (fonts.stage == 'download')
                      TextButton(
                        onPressed: fonts.cancelDownload,
                        child: Text(_text(context, '取消下载', 'Cancel download')),
                      ),
                  ],
                  if (fonts.error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      label: _error(context),
                      liveRegion: true,
                      excludeSemantics: true,
                      child: Text(
                        _error(context),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: tokens.lvError,
                        ),
                      ),
                    ),
                    if (fonts.error == 'download' &&
                        fonts.downloadAttempts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        _downloadDetails(context),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ],
                  if (fonts.installed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _text(context, '已加载字体', 'Loaded fonts'),
                      style: TextStyle(fontSize: 12, color: tokens.text),
                    ),
                    for (final font in fonts.installed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          font.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          '${mxFmtBytes(font.bytes)} · ${font.cached ? _text(context, '已缓存，可离线使用', 'Cached for offline use') : _text(context, '仅当前页面', 'This page only')}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: font.cached
                            ? IconButton(
                                tooltip: _text(
                                  context,
                                  '移除字体缓存',
                                  'Remove cached font',
                                ),
                                onPressed: fonts.busy
                                    ? null
                                    : () => fonts.removeCached(font.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                              )
                            : null,
                      ),
                    Text(
                      _text(
                        context,
                        '移除缓存后，本页仍可使用字体，下次打开不再加载。',
                        'Removing a cached font keeps it on this page, but it will not load next time.',
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: tokens.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_text(context, '完成', 'Done')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
