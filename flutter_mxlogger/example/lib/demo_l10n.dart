import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// demo 内置的语言管理: 默认英文 可在 App 内切换中文 与系统语言无关
/// (与 iOS / Android 原生 demo 行为一致)
///
/// [language] 变化后整棵 widget 树会重建 页面文案通过 [tr] 取当前语言。
class DemoL10n {
  DemoL10n._();

  static const String en = 'en';
  static const String zh = 'zh-Hans';

  static const String _fileName = 'mxlogger_demo_language.txt';

  /// 当前语言 默认英文
  static final ValueNotifier<String> language = ValueNotifier<String>(en);

  static bool get isChinese => language.value == zh;

  /// 切换按钮标题: 英文环境显示 "中文" 中文环境显示 "English"
  static String get switchButtonTitle => isChinese ? 'English' : '中文';

  /// 启动时读取上次选择 读不到(如 Web 无文件系统)时保持默认英文
  static Future<void> load() async {
    try {
      final file = await _storeFile();
      if (!await file.exists()) return;
      final saved = (await file.readAsString()).trim();
      if (saved == zh) language.value = zh;
    } catch (_) {
      // 持久化不可用时不影响功能 仅回到默认英文
    }
  }

  /// 切换语言并持久化
  static Future<void> toggle() async {
    language.value = isChinese ? en : zh;
    try {
      final file = await _storeFile();
      await file.writeAsString(language.value);
    } catch (_) {
      // 写入失败只影响下次启动的默认值
    }
  }

  static Future<File> _storeFile() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_fileName');
  }
}

/// 语言作用域: 语言变化时重建 [builder] 产出的子树。
///
/// 每个页面自己包一层，而不是只在根节点监听——根节点重建时
/// `const XxxPage()` 这类常量 widget 实例不变，子树会被短路而不重建。
class L10nScope extends StatelessWidget {
  const L10nScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: DemoL10n.language,
      builder: (context, _, __) => builder(context),
    );
  }
}

/// 取当前语言文案 `{0}` `{1}` 为占位符 按 [args] 顺序替换
/// 找不到 key 时原样返回 key 便于暴露漏翻
String tr(String key, [List<Object?> args = const []]) {
  final table = DemoL10n.isChinese ? _zhHans : _en;
  var text = table[key] ?? _en[key] ?? key;
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i]}');
  }
  return text;
}

const Map<String, String> _en = {
  // Landing
  'landing.subtitle': 'High-performance cross-platform log library based on mmap',
  'landing.enter': 'Enter Demo Console',

  // Common
  'common.cancel': 'Cancel',
  'common.ok': 'OK',
  'common.copy': 'Copy',
  'common.close': 'Close',
  'common.remove': 'Remove',
  'common.unlimited': 'Unlimited',
  'toast.copied': 'Copied',

  // Home - status card
  'home.title': 'MXLogger Demo',
  'home.card.size': 'Log Size',
  'home.card.files': 'Files',
  'home.card.level': 'Write Level',
  'home.card.policy': 'Policy',
  'home.card.policy.hourly': 'Hourly',
  'home.card.namespace.fmt': '{0} · AES-CFB 128 encryption',

  // Home - write section
  'home.section.write': 'Write Logs',
  'home.section.write.footer':
      'Each level has its own instance method; a return value of 0 means the write succeeded.',
  'home.write.level.title': 'Write {0} Log',
  'home.write.network.title': 'Write Network Request Log',
  'home.write.network.subtitle': 'msg is a JSON string, tag = request',
  'home.write.custom.title': 'log() Generic Write',
  'home.write.custom.subtitle': 'Write with a custom level, here level = 3 (error)',
  'home.write.key.title': 'Write via loggerKey',
  'home.write.key.subtitle':
      'Modular scenario: pass only the key, MXLogger.infoLog',

  // Home - config section
  'home.section.config': 'Configuration',
  'home.section.config.footer':
      'level only affects disk writes; with consoleEnable on, the console still prints all logs.',
  'home.config.level.title': 'Write Level (level)',
  'home.config.level.subtitle': 'Logs below this level are not written to file',
  'home.config.console.title': 'Console Output (consoleEnable)',
  'home.config.console.subtitle':
      'Affects write performance; disable in production',
  'home.config.enable.title': 'Master Switch (enable)',
  'home.config.enable.subtitle': 'When off, all log writing stops',
  'home.config.background.title': 'Clean Expired Files in Background',
  'home.config.age.title': 'Max Age (maxDiskAge)',
  'home.config.age.subtitle': 'Expired files will be removed; 0 = unlimited',
  'home.config.size.title': 'Disk Limit (maxDiskSize)',
  'home.config.size.subtitle':
      'Oldest files are removed first when over the limit; 0 = unlimited',

  // Home - benchmark section
  'home.section.perf': 'Benchmark',
  'home.section.perf.footer':
      'Disable consoleEnable before benchmarking; console output slows down writes significantly.',
  'home.perf.bench.title': 'Write 100,000 Logs',
  'home.perf.bench.subtitle':
      'Written on a background isolate, about 136 bytes each; measures total time',
  'home.perf.bench.running': 'Testing…',
  'home.perf.thread.title': 'Concurrent Multi-isolate Write',
  'home.perf.thread.subtitle':
      'Main isolate + 3 background isolates write concurrently; count and order are verified afterwards',
  'home.perf.thread.running': 'Writing…',

  // Home - file section
  'home.section.file': 'File Management',
  'home.file.browse.title': 'Browse Log Files',
  'home.file.browse.subtitle': 'getLogFiles + selectLogmsg parsing',
  'home.file.expire.title': 'Remove Expired Files',
  'home.file.before.title': 'Remove Historical Files',
  'home.file.before.subtitle':
      'removeBeforeAllData, keeps the file currently being written',
  'home.file.all.title': 'Remove All Logs',

  // Home - info section
  'home.section.info': 'Instance Info',
  'home.section.info.footer':
      'loggerKey = md5(namespace + directory); retrieve the instance across modules via loggerKey.',
  'home.info.path.title': 'Cache Directory (diskcachePath)',
  'home.info.error.title': 'Last Error (errorDesc)',
  'home.info.error.subtitle': 'Error description when a write returns non-zero',
  'home.info.rebuild.title': 'Destroy & Rebuild Instance',
  'home.info.rebuild.subtitle': 'initialize again after destroyWithLoggerKey',

  // Toasts
  'toast.console.on': 'Console output enabled',
  'toast.console.off': 'Console output disabled',
  'toast.enable.on': 'Logging enabled',
  'toast.enable.off': 'Logging disabled',
  'toast.expire.done': 'Expired files removed',
  'toast.before.done': 'Historical files removed',
  'toast.key.copied': 'loggerKey copied',
  'toast.path.copied': 'Path copied',
  'toast.rebuild.done': 'Instance rebuilt',
  'toast.removeall.done': 'All logs removed',
  'toast.write.success': '{0} written',
  'toast.network.success': 'Network log written',
  'toast.custom.success': 'log() written',
  'toast.key.success': 'Written via loggerKey',
  'toast.bench.done': '100,000 logs written in {0} ms',
  'toast.concurrent.running': 'Writing concurrently…',
  'toast.concurrent.verifying': 'Write finished, verifying…',

  // Alerts & pickers
  'alert.write.failed': 'Write Failed ({0})',
  'alert.no.error': 'No error',
  'alert.removeall.title': 'Remove all logs?',
  'alert.removeall.message':
      'removeAll deletes all log files and cannot be undone.',
  'picker.level.message': 'Logs below this level will not be written to disk',
  'picker.age.message': 'Maximum retention time of log files',
  'picker.size.message': 'Maximum disk usage of log files',
  'duration.1min': '1 minute',
  'duration.1hour': '1 hour',
  'duration.1day': '1 day',
  'duration.7days': '7 days',
  'duration.minutes.fmt': '{0} min',
  'duration.hours.fmt': '{0} h',
  'duration.days.fmt': '{0} d',

  // Concurrency verification
  'verify.pass.title': '✅ Concurrency Check Passed',
  'verify.fail.title': '❌ Concurrency Check Failed',
  'verify.no.file': 'No log file found',
  'verify.line.fmt': '{0}: {1}/{2} records {3}',
  'verify.line.ok': '✓ complete & ordered',
  'verify.line.order': '✗ order broken',
  'verify.line.missing': '✗ records missing',
  'verify.summary.fmt': 'File has {0} records, {1} sources verified',

  // Demo log content
  'log.msg.fmt': 'Log #{0} at {1} level, written at {2}',
  'log.pay.msg': 'Order payment failed: code=-1009 network connection lost',
  'log.module.msg': 'Log written by a sub-module via loggerKey',

  // File list
  'filelist.title': 'Log Files',
  'filelist.summary.fmt': '{0} files · total size {1}',
  'filelist.empty': 'No log files',
  'filelist.dates.fmt': 'Created {0} · Updated {1}',

  // Log viewer
  'viewer.title': 'Log Detail',
  'viewer.segment.all': 'All',
  'viewer.search.placeholder': 'Search msg / name / tag',
  'viewer.empty': 'No matching logs',
  'viewer.loading': 'Parsing…',

  // Record card
  'record.parse.failed.fmt': 'Parse failed: {0}',
  'record.thread.main': 'main',
  'record.thread.sub': 'background',
};

const Map<String, String> _zhHans = {
  // 落地页
  'landing.subtitle': '基于 mmap 的高性能跨平台日志库',
  'landing.enter': '进入演示控制台',

  // 通用
  'common.cancel': '取消',
  'common.ok': '好',
  'common.copy': '复制',
  'common.close': '关闭',
  'common.remove': '清空',
  'common.unlimited': '无限制',
  'toast.copied': '已复制',

  // 主页 - 状态卡片
  'home.title': 'MXLogger Demo',
  'home.card.size': '日志大小',
  'home.card.files': '文件数',
  'home.card.level': '写入等级',
  'home.card.policy': '分片策略',
  'home.card.policy.hourly': '按小时',
  'home.card.namespace.fmt': '{0} · AES-CFB 128 加密',

  // 主页 - 日志写入
  'home.section.write': '日志写入',
  'home.section.write.footer': '每个等级对应一个实例方法，返回 0 表示写入成功。',
  'home.write.level.title': '写入 {0} 日志',
  'home.write.network.title': '写入网络请求日志',
  'home.write.network.subtitle': 'msg 为 JSON 字符串，tag = request',
  'home.write.custom.title': 'log() 通用写入',
  'home.write.custom.subtitle': '自定义等级写入，本例 level = 3 (error)',
  'home.write.key.title': '通过 loggerKey 写入',
  'home.write.key.subtitle': '组件化场景：只传 key 不传对象，MXLogger.infoLog',

  // 主页 - 配置
  'home.section.config': '配置',
  'home.section.config.footer': 'level 只影响磁盘写入；开启 consoleEnable 后控制台仍输出全部日志。',
  'home.config.level.title': '写入等级 level',
  'home.config.level.subtitle': '低于该等级的日志不写入文件',
  'home.config.console.title': '控制台打印 consoleEnable',
  'home.config.console.subtitle': '影响写入性能，发布环境建议关闭',
  'home.config.enable.title': '日志总开关 enable',
  'home.config.enable.subtitle': '关闭后所有日志停止写入',
  'home.config.background.title': '进入后台清理过期文件',
  'home.config.age.title': '有效期 maxDiskAge',
  'home.config.age.subtitle': '超期文件将被清理，0 为无限制',
  'home.config.size.title': '容量上限 maxDiskSize',
  'home.config.size.subtitle': '超过上限按时间从旧到新清理，0 为无限制',

  // 主页 - 性能测试
  'home.section.perf': '性能测试',
  'home.section.perf.footer': '性能测试前建议关闭 consoleEnable，控制台输出会显著拖慢写入。',
  'home.perf.bench.title': '连续写入 100,000 条',
  'home.perf.bench.subtitle': '后台 isolate 写入，单条约 136 字节，统计总耗时',
  'home.perf.bench.running': '测试中…',
  'home.perf.thread.title': '多 isolate 并发写入',
  'home.perf.thread.subtitle': '主 isolate + 3 个后台 isolate 并发写入，完成后自动校验条数与顺序',
  'home.perf.thread.running': '写入中…',

  // 主页 - 文件管理
  'home.section.file': '文件管理',
  'home.file.browse.title': '浏览日志文件',
  'home.file.browse.subtitle': 'getLogFiles + selectLogmsg 解析',
  'home.file.expire.title': '清理过期文件',
  'home.file.before.title': '清理历史文件',
  'home.file.before.subtitle': 'removeBeforeAllData，保留当前写入中的文件',
  'home.file.all.title': '清空全部日志',

  // 主页 - 实例信息
  'home.section.info': '实例信息',
  'home.section.info.footer': 'loggerKey = md5(namespace + directory)，跨模块通过 loggerKey 找回实例。',
  'home.info.path.title': '缓存目录 diskcachePath',
  'home.info.error.title': '查看最近错误 errorDesc',
  'home.info.error.subtitle': '写入返回非 0 时的错误描述',
  'home.info.rebuild.title': '销毁并重建实例',
  'home.info.rebuild.subtitle': 'destroyWithLoggerKey 后重新 initialize',

  // Toast
  'toast.console.on': '已开启控制台打印',
  'toast.console.off': '已关闭控制台打印',
  'toast.enable.on': '日志已启用',
  'toast.enable.off': '日志已禁用',
  'toast.expire.done': '已清理过期文件',
  'toast.before.done': '已清理历史文件',
  'toast.key.copied': 'loggerKey 已复制',
  'toast.path.copied': '路径已复制',
  'toast.rebuild.done': '实例已重建',
  'toast.removeall.done': '日志已清空',
  'toast.write.success': '{0} 写入成功',
  'toast.network.success': '网络日志写入成功',
  'toast.custom.success': 'log() 写入成功',
  'toast.key.success': 'loggerKey 写入成功',
  'toast.bench.done': '10 万条写入耗时 {0} ms',
  'toast.concurrent.running': '并发写入中…',
  'toast.concurrent.verifying': '写入完成，正在解析校验…',

  // 弹窗与选择器
  'alert.write.failed': '写入失败({0})',
  'alert.no.error': '暂无错误',
  'alert.removeall.title': '清空全部日志？',
  'alert.removeall.message': 'removeAll 将删除所有日志文件，且不可恢复。',
  'picker.level.message': '低于该等级的日志不会写入磁盘文件',
  'picker.age.message': '日志文件最长保留时间',
  'picker.size.message': '日志文件占用磁盘上限',
  'duration.1min': '1 分钟',
  'duration.1hour': '1 小时',
  'duration.1day': '1 天',
  'duration.7days': '7 天',
  'duration.minutes.fmt': '{0} 分钟',
  'duration.hours.fmt': '{0} 小时',
  'duration.days.fmt': '{0} 天',

  // 并发校验
  'verify.pass.title': '✅ 并发校验通过',
  'verify.fail.title': '❌ 并发校验失败',
  'verify.no.file': '未找到日志文件',
  'verify.line.fmt': '{0}: {1}/{2} 条 {3}',
  'verify.line.ok': '✓ 顺序完整',
  'verify.line.order': '✗ 顺序异常',
  'verify.line.missing': '✗ 条数缺失',
  'verify.summary.fmt': '文件共 {0} 条，校验来源 {1} 个',

  // 演示日志内容
  'log.msg.fmt': '这是第 {0} 条 {1} 日志，写于 {2}',
  'log.pay.msg': '订单支付失败: code=-1009 网络连接中断',
  'log.module.msg': '子组件通过 loggerKey 写入的日志',

  // 文件列表
  'filelist.title': '日志文件',
  'filelist.summary.fmt': '共 {0} 个文件 · 总大小 {1}',
  'filelist.empty': '暂无日志文件',
  'filelist.dates.fmt': '创建 {0} · 更新 {1}',

  // 日志查看器
  'viewer.title': '日志详情',
  'viewer.segment.all': '全部',
  'viewer.search.placeholder': '搜索 msg / name / tag',
  'viewer.empty': '没有匹配的日志',
  'viewer.loading': '日志解析中…',

  // 日志记录卡片
  'record.parse.failed.fmt': '数据解析失败: {0}',
  'record.thread.main': '主线程',
  'record.thread.sub': '子线程',
};
