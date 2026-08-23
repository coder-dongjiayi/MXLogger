import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

import 'demo_l10n.dart';
import 'demo_util.dart';

/// 日志查看器: selectLogmsg 解析(解密)日志文件
/// 返回字段: name / msg / tag / level / timestamp / is_main_thread / thread_id / error_code
/// error_code 非 0 表示该条数据解析失败(可能是 cryptKey 或 iv 不正确)
class LogViewerPage extends StatefulWidget {
  const LogViewerPage(
      {super.key,
      required this.filePath,
      required this.fileName,
      this.cryptKey,
      this.iv});

  final String filePath;
  final String fileName;
  final String? cryptKey;
  final String? iv;

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

/// isolate 入口(顶层函数): 闭包只捕获参数，不能在 State 方法里创建，
/// 否则会把 State/Element 一起捕获导致 isolate 消息发送失败
Future<List<Map<String, dynamic>>> _selectRecords(
    String path, String? cryptKey, String? iv) {
  return Isolate.run(() => MXLogger.selectLogmsg(
      diskcacheFilePath: path, cryptKey: cryptKey, iv: iv));
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<Map<String, dynamic>> _all = const [];
  List<Map<String, dynamic>> _filtered = const [];
  bool _loading = true;
  int _levelFilter = -1; // -1 全部, 0~4 对应等级
  String _keyword = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 大文件解析可能耗时较长，放到后台 isolate 执行，解析期间展示 loading
    final records =
        await _selectRecords(widget.filePath, widget.cryptKey, widget.iv);
    if (!mounted) return;
    setState(() {
      _all = records;
      _loading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    _filtered = _all.where((record) {
      if (_levelFilter >= 0 && _recordInt(record, 'level') != _levelFilter) {
        return false;
      }
      if (_keyword.isNotEmpty) {
        final haystack =
            '${record['msg'] ?? ''} ${record['name'] ?? ''} ${record['tag'] ?? ''}'
                .toLowerCase();
        if (!haystack.contains(_keyword.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  int _recordInt(Map<String, dynamic> record, String key) =>
      int.tryParse(record[key]?.toString() ?? '') ?? 0;

  void _showDetail(Map<String, dynamic> record) {
    final msg = (record['msg'] ?? '').toString();
    final name = (record['name'] ?? '').toString();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(name.isEmpty ? tr('viewer.title') : name,
            style: const TextStyle(fontSize: 16)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.5),
          child: SingleChildScrollView(
              child:
                  SelectableText(msg, style: const TextStyle(fontSize: 13))),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: msg));
              Navigator.of(dialogContext).pop();
              showToast(context, tr('toast.copied'));
            },
            child: Text(tr('common.copy')),
          ),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('common.close'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => L10nScope(builder: _build);

  Widget _build(BuildContext context) {
    final title =
        _loading ? widget.fileName : '${widget.fileName} (${_all.length})';
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: groupedBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _filterBar(),
          Expanded(
            child: _loading
                ? _loadingView()
                : _filtered.isEmpty
                    ? Center(
                        child: Text(tr('viewer.empty'),
                            style: TextStyle(
                                fontSize: 14, color: secondaryText(context))))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _recordCard(_filtered[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    final labels = [tr('viewer.segment.all'), ...kLevelNames];
    return Column(
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final selected = _levelFilter == index - 1;
              final color =
                  index == 0 ? kBrandColor : kLevelColors[index - 1];
              return GestureDetector(
                onTap: _loading
                    ? null
                    : () => setState(() {
                          _levelFilter = index - 1;
                          _applyFilter();
                        }),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? color : cardBg(context),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(labels[index],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected
                              ? Colors.white
                              : secondaryText(context))),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (text) => setState(() {
              _keyword = text;
              _applyFilter();
            }),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: tr('viewer.search.placeholder'),
              hintStyle:
                  TextStyle(fontSize: 14, color: tertiaryText(context)),
              prefixIcon:
                  Icon(Icons.search, size: 20, color: tertiaryText(context)),
              isDense: true,
              filled: true,
              fillColor: cardBg(context),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(height: 14),
          Text(tr('viewer.loading'),
              style: TextStyle(fontSize: 13, color: secondaryText(context))),
        ],
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final level = _recordInt(record, 'level');
    final parseFailed = _recordInt(record, 'error_code') != 0;
    final badge = parseFailed
        ? 'BAD'
        : (level >= 0 && level < kLevelBadges.length)
            ? kLevelBadges[level]
            : '?';
    final badgeColor = parseFailed
        ? kLevelColors[3]
        : (level >= 0 && level < kLevelColors.length)
            ? kLevelColors[level]
            : kLevelColors[0];
    final name = (record['name'] ?? '').toString();
    final msg = (record['msg'] ?? '').toString();
    final tag = (record['tag'] ?? '').toString();
    final isMain = record['is_main_thread']?.toString() == '1';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetail(record),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: cardBg(context), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name.isEmpty ? '-' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryText(context))),
                ),
                const SizedBox(width: 8),
                Text(dateText(record['timestamp'], withMillis: true),
                    style: TextStyle(
                        fontSize: 11,
                        color: secondaryText(context),
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
            const SizedBox(height: 6),
            Text(parseFailed ? tr('record.parse.failed.fmt', [msg]) : msg,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: primaryText(context))),
            const SizedBox(height: 6),
            Row(
              children: [
                if (tag.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: secondaryText(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('# $tag',
                        style: TextStyle(
                            fontSize: 11, color: secondaryText(context))),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                    '${tr(isMain ? 'record.thread.main' : 'record.thread.sub')}'
                    ' · tid ${record['thread_id'] ?? '-'}',
                    style: TextStyle(
                        fontSize: 11, color: tertiaryText(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
