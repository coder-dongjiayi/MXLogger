import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 桌面壳的宿主能力实现：内核（mxlogger_analyzer_lib）不依赖这些插件，
/// 选文件 / 拖入 / 设置落盘 / 系统分享统一在这里用 file_picker /
/// desktop_drop / shared_preferences / share_plus 实现后注入 [MXHost]。
Future<MXHost> createDesktopHost() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return MXHost(
    prefs: _SharedPrefsAdapter(prefs),
    pickLogFiles: _pickLogFiles,
    dropTargetBuilder: _buildDropTarget,
    share: _share,
  );
}

/// SharedPreferences 适配为内核的 MXPrefs（写入 fire-and-forget，同原用法）
class _SharedPrefsAdapter implements MXPrefs {
  _SharedPrefsAdapter(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  void setString(String key, String value) => _prefs.setString(key, value);

  @override
  void setBool(String key, bool value) => _prefs.setBool(key, value);
}

/// 系统分享面板：携带 fileName 时以文本文件分享，否则分享纯文本。
/// 返回 false（分享在当前环境不可用）时内核会降级复制到剪贴板。
Future<bool> _share(MXShareRequest request) async {
  final ShareResult result;
  if (request.fileName != null) {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(request.text)),
          name: request.fileName,
          mimeType: "text/plain",
        ),
      ],
      fileNameOverrides: [request.fileName!],
      sharePositionOrigin: request.origin,
    ));
  } else {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      text: request.text,
      sharePositionOrigin: request.origin,
    ));
  }
  return result.status != ShareResultStatus.unavailable;
}

Future<List<String>> _pickLogFiles() async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: ["mx", "log", "txt", "json"],
  );
  return result?.files
          .map((PlatformFile file) => file.path)
          .whereType<String>()
          .toList() ??
      <String>[];
}

/// 契约：指针进出目标回调 onDragOver(true/false)，
/// 文件落下先复位高亮再以非空绝对路径列表回调 onDrop。
Widget _buildDropTarget({
  required Widget child,
  required ValueChanged<List<String>> onDrop,
  required ValueChanged<bool> onDragOver,
}) {
  return DropTarget(
    onDragEntered: (_) => onDragOver(true),
    onDragExited: (_) => onDragOver(false),
    onDragDone: (DropDoneDetails details) {
      onDragOver(false);
      final List<String> paths = details.files
          .map((file) => file.path)
          .where((String path) => path.isNotEmpty)
          .toList();
      if (paths.isNotEmpty) onDrop(paths);
    },
    child: child,
  );
}
