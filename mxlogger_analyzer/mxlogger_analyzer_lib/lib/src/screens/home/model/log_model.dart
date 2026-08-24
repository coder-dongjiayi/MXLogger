import 'package:mxlogger_analyzer_lib/src/global/level/mx_level.dart';
import 'package:mxlogger_analyzer_lib/src/global/util/mx_format.dart';

/// 单条日志展示模型，由 sqlite 行构造。
class LogModel {
  const LogModel({
    this.id,
    this.name,
    this.tag,
    this.msg,
    required this.level,
    this.threadId,
    this.isMainThread,
    required this.timestamp,
    this.fileHeader,
  });

  factory LogModel.fromJson(Map<String, Object?> json) {
    return LogModel(
      id: json["id"] as int?,
      name: json["name"] as String?,
      tag: json["tag"] as String?,
      msg: json["msg"] as String?,
      level: json["level"] as int? ?? 0,
      threadId: json["threadId"] as int?,
      isMainThread: json["isMainThread"] as int?,
      timestamp: json["timestamp"] as int? ?? 0,
      fileHeader: json["fileHeader"] as String?,
    );
  }

  final int? id;
  final String? name;
  final String? tag;
  final String? msg;
  final int level;
  final int? threadId;
  final int? isMainThread;

  /// 微秒时间戳
  final int timestamp;
  final String? fileHeader;

  DateTime get dateTime => DateTime.fromMicrosecondsSinceEpoch(timestamp);

  MxTimeParts get timeParts => mxFmtTs(dateTime);

  String get levelName => mxLevelName(level);

  /// tag 列按逗号/空格分词：写入端多 tag 用逗号分隔（如 "net,login"），
  /// 拆成独立 tag 后展示与点击过滤都按单个 tag 处理
  List<String> get tags {
    final String raw = tag?.trim() ?? "";
    if (raw.isEmpty) return const [];
    return raw
        .split(RegExp(r"[,\s]+"))
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  /// 折叠时的单行缩略
  String get preview => mxPreviewOf(msg);

  /// 复制/分享的纯文本格式（对齐设计稿 logToText）
  String toShareText() {
    final String tagText = tags.map((String t) => "#$t").join(" ");
    return "[${timeParts.full}] [$levelName] [${name ?? "-"}] $tagText ${msg ?? ""}";
  }
}
