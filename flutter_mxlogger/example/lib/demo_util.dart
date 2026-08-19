import 'package:flutter/material.dart';

/// demo 初始化常量(与 iOS / Android 原生 demo 保持一致)
const String kDemoNamespace = 'com.djy.mxlogger';
const String kDemoCryptKey = 'abcdefgabcdefgob';
const String kDemoIV = 'abcdefgabcdefgcc';

/// 品牌色
const Color kBrandColor = Color(0xFF4F46E5);

/// 等级颜色: debug/info/warn/error/fatal (与 iOS / Android demo 一致)
const List<Color> kLevelColors = [
  Color(0xFF8E8E93),
  Color(0xFF007AFF),
  Color(0xFFFF9500),
  Color(0xFFFF3B30),
  Color(0xFFAF52DE),
];

const List<String> kLevelNames = ['Debug', 'Info', 'Warn', 'Error', 'Fatal'];
const List<String> kLevelBadges = ['DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'];

String levelName(int level) =>
    (level >= 0 && level < kLevelNames.length) ? kLevelNames[level] : 'Debug';

String byteText(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

String diskAgeText(int seconds) {
  if (seconds == 0) return '无限制';
  if (seconds < 3600) return '${seconds ~/ 60} 分钟';
  if (seconds < 86400) return '${seconds ~/ 3600} 小时';
  return '${seconds ~/ 86400} 天';
}

String diskSizeText(int bytes) => bytes == 0 ? '无限制' : byteText(bytes);

String _two(int n) => n.toString().padLeft(2, '0');

/// 时间戳格式化。
/// 日志记录的 timestamp 是微秒(core 用 time_stamp_microseconds 写入)，
/// 文件的 create/last_timestamp 是秒(来自文件系统)，按量级自动识别。
String dateText(dynamic timestamp, {bool withMillis = false}) {
  final value = double.tryParse(timestamp?.toString() ?? '');
  if (value == null) return timestamp?.toString() ?? '-';
  if (value <= 0) return '-';
  double seconds = value;
  if (value > 1e14) {
    seconds = value / 1e6; // 微秒
  } else if (value > 1e11) {
    seconds = value / 1e3; // 毫秒
  }
  final date = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  final base = '${_two(date.month)}-${_two(date.day)} '
      '${_two(date.hour)}:${_two(date.minute)}:${_two(date.second)}';
  if (!withMillis) return base;
  return '$base.${date.millisecond.toString().padLeft(3, '0')}';
}

String timeNowText() {
  final now = DateTime.now();
  return '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
}

String joinPath(String directory, String name) =>
    directory.endsWith('/') ? '$directory$name' : '$directory/$name';

// ---- 主题辅助(对齐 iOS systemGroupedBackground 风格) ----

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color groupedBg(BuildContext context) =>
    _isDark(context) ? Colors.black : const Color(0xFFF2F2F7);

Color cardBg(BuildContext context) =>
    _isDark(context) ? const Color(0xFF1C1C1E) : Colors.white;

Color primaryText(BuildContext context) =>
    _isDark(context) ? Colors.white : const Color(0xFF1C1C1E);

Color secondaryText(BuildContext context) =>
    _isDark(context) ? const Color(0xFF9B9BA1) : const Color(0xFF6C6C70);

Color tertiaryText(BuildContext context) =>
    _isDark(context) ? const Color(0xFF636366) : const Color(0xFFAEAEB2);

Color demoDividerColor(BuildContext context) =>
    _isDark(context) ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

/// 底部悬浮 toast(对齐 iOS demo 的黑色胶囊提示)
void showToast(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.black.withValues(alpha: 0.78),
    shape: const StadiumBorder(),
    margin: const EdgeInsets.only(left: 48, right: 48, bottom: 90),
    duration: const Duration(milliseconds: 1600),
  ));
}
