import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

import 'demo_l10n.dart';
import 'demo_util.dart';
import 'log_viewer_page.dart';

/// 日志文件列表: getLogFiles 返回 name / size / createTimeStamp / lastTimeStamp
class LogFileListPage extends StatefulWidget {
  const LogFileListPage(
      {super.key, required this.logger, this.cryptKey, this.iv});

  final MXLogger logger;
  final String? cryptKey;
  final String? iv;

  @override
  State<LogFileListPage> createState() => _LogFileListPageState();
}

class _LogFileListPageState extends State<LogFileListPage> {
  List<MXFileEntity> _files = const [];
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // 按最后更新时间倒序，最新的文件排在最上面
    final files = widget.logger.getLogFiles()
      ..sort((a, b) => b.lastTimeStamp.compareTo(a.lastTimeStamp));
    setState(() {
      _files = files;
      _totalSize = files.fold<int>(0, (sum, file) => sum + file.size);
    });
  }

  Future<void> _openViewer(MXFileEntity file) async {
    final name = file.name ?? '';
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LogViewerPage(
              filePath: joinPath(widget.logger.diskcachePath, name),
              fileName: name,
              cryptKey: widget.cryptKey,
              iv: widget.iv,
            )));
    _reload();
  }

  @override
  Widget build(BuildContext context) => L10nScope(builder: _build);

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        title: Text(tr('filelist.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: groupedBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
                tr('filelist.summary.fmt',
                    [_files.length, byteText(_totalSize)]),
                style: TextStyle(fontSize: 13, color: secondaryText(context))),
          ),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Text(tr('filelist.empty'),
                        style: TextStyle(
                            fontSize: 14, color: secondaryText(context))))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            color: cardBg(context),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          children: [
                            for (var i = 0; i < _files.length; i++) ...[
                              if (i > 0)
                                Divider(
                                    height: 0.5,
                                    thickness: 0.5,
                                    indent: 62,
                                    color: demoDividerColor(context)),
                              _fileRow(_files[i]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _fileRow(MXFileEntity file) {
    return InkWell(
      onTap: () => _openViewer(file),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: kBrandColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description, size: 20, color: kBrandColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.name ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryText(context))),
                  const SizedBox(height: 3),
                  Text(
                      tr('filelist.dates.fmt', [
                        dateText(file.createTimeStamp),
                        dateText(file.lastTimeStamp)
                      ]),
                      style: TextStyle(
                          fontSize: 11, color: secondaryText(context))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(byteText(file.size),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryText(context))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: tertiaryText(context)),
          ],
        ),
      ),
    );
  }
}
