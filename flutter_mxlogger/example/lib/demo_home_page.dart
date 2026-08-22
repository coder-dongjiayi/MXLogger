import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

import 'demo_l10n.dart';
import 'demo_util.dart';
import 'log_file_list_page.dart';

/// MXLogger 全功能演示主页(与 iOS / Android 原生 demo 保持一致)
/// 覆盖的 API:
///  - MXLogger.initialize / destroyWithLoggerKey
///  - debug / info / warn / error / fatal / log
///  - MXLogger.infoLog 等通过 loggerKey 的类方法写入
///  - setLevel / setConsoleEnable / setEnable / shouldRemoveExpiredDataWhenEnterBackground
///  - setMaxDiskAge / setMaxDiskSize / logSize / diskcachePath / loggerKey / errorDesc
///  - getLogFiles / selectLogmsg
///  - removeExpireData / removeBeforeAllData / removeAll
/// 控制台输出是否可用: 只有 debug 构建才有。
/// - flutter 层 MXLogger._consolePrint 以 kDebugMode 短路，release/profile 构建
///   整段连同调用点被 AOT tree-shake 掉；
/// - native 层的控制台在初始化时就被显式关闭(输出统一由 flutter 层 debugPrint 发出)，
///   且 iOS 的 native 控制台在 Release 配置下本身也已在编译期被裁掉。
/// 所以 release/profile 下 setConsoleEnable(true) 不会有任何输出，
/// demo 直接把开关置灰并说明原因，避免误以为"打开了却没日志"。
///
/// Whether console output is available at all: debug builds only.
/// - MXLogger._consolePrint short-circuits on kDebugMode, so AOT tree-shakes the whole
///   body and its call sites out of release/profile builds;
/// - native console output is explicitly disabled at initialization (everything is
///   printed from the Flutter layer instead), and on iOS the native console is stripped
///   at compile time in the Release configuration anyway.
/// setConsoleEnable(true) therefore prints nothing in release/profile, so the demo greys
/// the switch out and explains why instead of leaving users wondering.
const bool kConsoleAvailable = kDebugMode;

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  MXLogger? _logger;
  String _loggerKey = '';
  String _diskCachePath = '';

  int _level = 0;
  bool _consoleOn = kConsoleAvailable;
  bool _enableOn = true;
  bool _backgroundCleanOn = true;
  int _maxDiskAge = 60 * 60 * 24 * 7;
  int _maxDiskSize = 1024 * 1024 * 10;

  int _writeCount = 0; // 本次会话写入条数
  String? _perfResult; // 10万条写入耗时
  bool _benchRunning = false;
  bool _concurrentRunning = false;

  String _sizeText = '-';
  int _fileCount = 0;

  @override
  void initState() {
    super.initState();
    _setupLogger();
  }

  @override
  void dispose() {
    if (_loggerKey.isNotEmpty) {
      MXLogger.destroyWithLoggerKey(_loggerKey);
    }
    super.dispose();
  }

  // ---------------- Logger ----------------

  Future<void> _setupLogger() async {
    // 文件头信息: 文件创建时会写入，一般放 App 版本、平台等业务信息
    final fileHeader = jsonEncode({
      'platform': Platform.operatingSystem,
      'appVersion': '2.0.0',
      'systemVersion': Platform.operatingSystemVersion,
      'from': 'flutter-demo',
    });

    // 按小时分片存储 + AES CFB-128 加密(与原生 demo 相同参数)
    final logger = await MXLogger.initialize(
        nameSpace: kDemoNamespace,
        consoleEnable: kConsoleAvailable,
        storagePolicy: MXStoragePolicyType.yyyy_MM_dd_HH,
        fileHeader: fileHeader,
        cryptKey: kDemoCryptKey,
        iv: kDemoIV);

    logger.setMaxDiskAge(60 * 60 * 24 * 7); // 日志最多保留 7 天
    logger.setMaxDiskSize(1024 * 1024 * 10); // 日志最多占用 10 MB
    logger.setLevel(0); // 0:debug 全部写入
    logger.shouldRemoveExpiredDataWhenEnterBackground(true);

    if (!mounted) return;
    setState(() {
      _logger = logger;
      _loggerKey = logger.loggerKey ?? '';
      _diskCachePath = logger.diskcachePath;
      _level = 0;
      _consoleOn = kConsoleAvailable;
      _enableOn = true;
      _backgroundCleanOn = true;
      _maxDiskAge = 60 * 60 * 24 * 7;
      _maxDiskSize = 1024 * 1024 * 10;
    });
    _refreshStatus();
  }

  void _refreshStatus() {
    final logger = _logger;
    if (logger == null || !mounted) return;
    setState(() {
      _sizeText = byteText(logger.logSize);
      _fileCount = logger.getLogFiles().length;
    });
  }

  // ---------------- 写入动作 ----------------

  void _writeLevelLog(int level) {
    final logger = _logger;
    if (logger == null) return;
    const name = 'mxlogger';
    const tag = 'demo';
    final msg =
        tr('log.msg.fmt', [_writeCount + 1, levelName(level), timeNowText()]);
    int result;
    switch (level) {
      case 0:
        result = logger.debug(msg, name: name, tag: tag);
      case 1:
        result = logger.info(msg, name: name, tag: tag);
      case 2:
        result = logger.warn(msg, name: name, tag: tag);
      case 3:
        result = logger.error(msg, name: name, tag: tag);
      default:
        result = logger.fatal(msg, name: name, tag: tag);
    }
    _handleWriteResult(result, tr('toast.write.success', [levelName(level)]));
  }

  void _writeNetworkLog() {
    final request = {
      'uri': 'https://api.example.com/v1/login',
      'method': 'POST',
      'statusCode': 200,
      'costTime': '183ms',
      'requestHeaders': {
        'content-type': 'application/json',
        'token': 'eyJhbGciOi...'
      },
      'requestBody': {'mobile': '188****8888'},
      'response': {'code': 0, 'msg': 'ok'},
    };
    final json = const JsonEncoder.withIndent('  ').convert(request);
    final result = _logger?.info(json, name: 'network', tag: 'request') ?? 0;
    _handleWriteResult(result, tr('toast.network.success'));
  }

  void _writeCustomLevelLog() {
    // log() 是所有便捷方法的底层通用入口
    final result =
        _logger?.log(3, tr('log.pay.msg'), name: 'pay', tag: 'order') ?? 0;
    _handleWriteResult(result, tr('toast.custom.success'));
  }

  void _writeByLoggerKey() {
    // 业务组件不持有 logger 对象，只拿一个字符串 key 即可写入
    MXLogger.infoLog(_loggerKey, tr('log.module.msg'),
        name: 'module.user', tag: 'module');
    _handleWriteResult(0, tr('toast.key.success'));
  }

  void _handleWriteResult(int result, String successText) {
    if (result == 0) {
      _writeCount += 1;
      showToast(context, successText);
    } else {
      // -1 扩容失败 -2 解除映射失败 -3 映射失败
      _showAlert(tr('alert.write.failed', [result]), _logger?.errorDesc ?? '');
    }
    _refreshStatus();
  }

  // ---------------- 性能测试 ----------------

  Future<void> _runBenchmark() async {
    if (_benchRunning || _logger == null) return;
    final consoleWasOn = _consoleOn;
    _logger!.setConsoleEnable(false); // 控制台输出会严重拖慢写入，测试期间临时关闭
    setState(() {
      _benchRunning = true;
    });

    // 写入放到后台 isolate 避免卡 UI。isolate 里没有实例对象，
    // 通过 loggerKey 走类方法写入(与主 isolate 是底层同一个 logger)
    final cost = await _spawnBenchmark(_loggerKey);

    if (!mounted) return;
    _logger!.setConsoleEnable(consoleWasOn);
    _writeCount += 100000;
    setState(() {
      _benchRunning = false;
      _perfResult = '$cost ms';
    });
    _refreshStatus();
    showToast(context, tr('toast.bench.done', [cost]));
  }

  /// 模拟真实 App 的多来源并发日志: 主 isolate(UI 事件) + 3 个后台 isolate(网络回调/后台任务)。
  /// 每条日志带 "#序号"，写入期间随机 sleep 扰动调度、穿插 getLogFiles 读取，
  /// 结束后解析当前日志文件，逐来源校验条数与顺序，给出可信的并发安全结论。
  Future<void> _runConcurrentWrite() async {
    if (_concurrentRunning || _logger == null) return;
    final consoleWasOn = _consoleOn;
    _logger!.setConsoleEnable(false);
    setState(() => _concurrentRunning = true);

    // 每轮用随机 runName 作为 name 字段，避免与历史数据混淆
    final runName =
        'mt-${Random().nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0')}';
    const sources = <String, int>{
      'isolate-fast': 1000,
      'isolate-normal': 1000,
      'isolate-slow': 1000,
    };
    const mainCount = 200; // 主 isolate 写少一些，避免长时间卡 UI

    showToast(context, tr('toast.concurrent.running'));
    await Future.wait([
      for (final source in sources.entries)
        _spawnConcurrentWorker(_loggerKey, runName, source.key, source.value),
      _writeOnMainIsolate(runName, mainCount),
    ]);

    if (!mounted) return;
    _logger!.setConsoleEnable(consoleWasOn);
    _writeCount += sources.values.fold<int>(0, (a, b) => a + b) + mainCount;
    setState(() => _concurrentRunning = false);
    _refreshStatus();
    await _verifyConcurrent(runName, {...sources, 'main': mainCount});
  }

  /// 主 isolate 来源: 模拟 UI 事件里打日志，边写边读 getLogFiles
  Future<void> _writeOnMainIsolate(String runName, int total) async {
    for (var i = 1; i <= total; i++) {
      _logger!.info('#${'$i'.padLeft(5, '0')} main concurrent write',
          name: runName, tag: 'main');
      if (i % 50 == 0) {
        _logger!.getLogFiles(); // 覆盖"写入与查询并发"的场景
        await Future<void>.delayed(Duration.zero); // 让出事件循环，保持 UI 响应
      }
    }
  }

  /// 解析当前日志文件，按来源校验: 条数是否等于预期、序号是否连续(单来源内顺序不被打乱)
  Future<void> _verifyConcurrent(
      String runName, Map<String, int> expected) async {
    showToast(context, tr('toast.concurrent.verifying'));
    final logger = _logger!;

    // 找到最后更新的文件(当前写入中的文件)
    MXFileEntity? latest;
    for (final file in logger.getLogFiles()) {
      if (latest == null || file.lastTimeStamp > latest.lastTimeStamp) {
        latest = file;
      }
    }
    if (latest == null) {
      await _showAlert(tr('verify.fail.title'), tr('verify.no.file'));
      return;
    }
    final path = joinPath(logger.diskcachePath, latest.name ?? '');

    // 解析放到后台 isolate，大文件解析不卡 UI
    final parsed = await _parseRunRecords(path, runName);

    // 逐来源校验。注意: selectLogmsg 返回"最新的在前"(倒序)，
    // 因此单个来源的序号应严格递减: N, N-1, ..., 1
    var allPass = true;
    final report = StringBuffer();
    final tags = expected.keys.toList()..sort();
    for (final tag in tags) {
      final expectCount = expected[tag]!;
      final sequence = parsed.seqs[tag] ?? const <int>[];
      final countOK = sequence.length == expectCount;
      var orderOK = countOK;
      if (countOK) {
        var next = expectCount;
        for (final seq in sequence) {
          if (seq != next--) {
            orderOK = false;
            break;
          }
        }
      }
      if (!countOK || !orderOK) allPass = false;
      final state = (countOK && orderOK)
          ? tr('verify.line.ok')
          : (countOK ? tr('verify.line.order') : tr('verify.line.missing'));
      report.writeln(
          tr('verify.line.fmt', [tag, sequence.length, expectCount, state]));
    }
    report.write('\n${tr('verify.summary.fmt', [parsed.total, tags.length])}');

    if (!mounted) return;
    await _showAlert(
        tr(allPass ? 'verify.pass.title' : 'verify.fail.title'),
        report.toString());
  }

  // ---------------- 配置动作 ----------------

  Future<void> _pickLevel() async {
    final selected = await _showOptionsSheet<int>(
        tr('home.config.level.title'), tr('picker.level.message'),
        [for (var l = 0; l <= 4; l++) MapEntry('${levelName(l)} ($l)', l)]);
    if (selected == null) return;
    _logger?.setLevel(selected);
    setState(() => _level = selected);
  }

  Future<void> _pickDiskAge() async {
    final selected = await _showOptionsSheet<int>(
        'maxDiskAge', tr('picker.age.message'), [
      MapEntry(tr('duration.1min'), 60),
      MapEntry(tr('duration.1hour'), 3600),
      MapEntry(tr('duration.1day'), 86400),
      MapEntry(tr('duration.7days'), 604800),
      MapEntry(tr('common.unlimited'), 0),
    ]);
    if (selected == null) return;
    _logger?.setMaxDiskAge(selected);
    setState(() => _maxDiskAge = selected);
  }

  Future<void> _pickDiskSize() async {
    final selected = await _showOptionsSheet<int>(
        'maxDiskSize', tr('picker.size.message'), [
      const MapEntry('1 MB', 1024 * 1024),
      const MapEntry('10 MB', 1024 * 1024 * 10),
      const MapEntry('100 MB', 1024 * 1024 * 100),
      MapEntry(tr('common.unlimited'), 0),
    ]);
    if (selected == null) return;
    _logger?.setMaxDiskSize(selected);
    setState(() => _maxDiskSize = selected);
  }

  // ---------------- 文件管理 ----------------

  Future<void> _openFileList() async {
    final logger = _logger;
    if (logger == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LogFileListPage(
            logger: logger, cryptKey: kDemoCryptKey, iv: kDemoIV)));
    _refreshStatus();
  }

  Future<void> _confirmRemoveAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('alert.removeall.title')),
        content: Text(tr('alert.removeall.message')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr('common.remove'),
                  style: TextStyle(color: kLevelColors[3]))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _logger?.removeAll();
    _writeCount = 0;
    _refreshStatus();
    showToast(context, tr('toast.removeall.done'));
  }

  // ---------------- 实例信息 ----------------

  Future<void> _rebuildLogger() async {
    // 通过 loggerKey 释放底层实例，再重新 initialize
    MXLogger.destroyWithLoggerKey(_loggerKey);
    setState(() => _logger = null);
    await _setupLogger();
    if (!mounted) return;
    showToast(context, tr('toast.rebuild.done'));
  }

  void _copyText(String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    showToast(context, toast);
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) => L10nScope(builder: _build);

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: groupedBg(context),
      appBar: AppBar(
        title: Text(tr('home.title'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: groupedBg(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: const [LanguageToggleButton(), SizedBox(width: 8)],
      ),
      body: _logger == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                _statusCard(),
                _section(tr('home.section.write'),
                    footer: tr('home.section.write.footer'),
                    rows: _writeRows()),
                _section(tr('home.section.config'),
                    footer: tr(kConsoleAvailable
                        ? 'home.section.config.footer'
                        : 'home.section.config.footer.release'),
                    rows: _configRows()),
                _section(tr('home.section.perf'),
                    footer: tr('home.section.perf.footer'),
                    rows: _perfRows()),
                _section(tr('home.section.file'), rows: _fileRows()),
                _section(tr('home.section.info'),
                    footer: tr('home.section.info.footer'),
                    rows: _infoRows()),
              ],
            ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
            colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(
              color: kBrandColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset('assets/mxlogger_logo.png',
                    width: 40, height: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MXLogger',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(tr('home.card.namespace.fmt', [kDemoNamespace]),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('mmap',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _stat(tr('home.card.size'), _sizeText),
              _stat(tr('home.card.files'), '$_fileCount'),
              _stat(tr('home.card.level'), levelName(_level)),
              _stat(tr('home.card.policy'), tr('home.card.policy.hourly')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }

  List<Widget> _writeRows() {
    const icons = [
      Icons.bug_report,
      Icons.info,
      Icons.warning_amber_rounded,
      Icons.cancel,
      Icons.local_fire_department,
    ];
    const methods = ['debug', 'info', 'warn', 'error', 'fatal'];
    return [
      for (var level = 0; level < 5; level++)
        _actionRow(
          icon: icons[level],
          tint: kLevelColors[level],
          title: tr('home.write.level.title', [levelName(level)]),
          subtitle: '${methods[level]}(msg, name:, tag:)',
          onTap: () => _writeLevelLog(level),
        ),
      _actionRow(
        icon: Icons.wifi,
        tint: const Color(0xFF30B0C7),
        title: tr('home.write.network.title'),
        subtitle: tr('home.write.network.subtitle'),
        onTap: _writeNetworkLog,
      ),
      _actionRow(
        icon: Icons.tune,
        tint: kBrandColor,
        title: tr('home.write.custom.title'),
        subtitle: tr('home.write.custom.subtitle'),
        onTap: _writeCustomLevelLog,
      ),
      _actionRow(
        icon: Icons.key,
        tint: const Color(0xFFA2845E),
        title: tr('home.write.key.title'),
        subtitle: tr('home.write.key.subtitle'),
        onTap: _writeByLoggerKey,
      ),
    ];
  }

  List<Widget> _configRows() {
    return [
      _actionRow(
        icon: Icons.filter_alt,
        tint: kLevelColors[1],
        title: tr('home.config.level.title'),
        subtitle: tr('home.config.level.subtitle'),
        value: levelName(_level),
        onTap: _pickLevel,
      ),
      _switchRow(
        icon: Icons.terminal,
        tint: kLevelColors[0],
        title: tr('home.config.console.title'),
        subtitle: tr(kConsoleAvailable
            ? 'home.config.console.subtitle'
            : 'home.config.console.subtitle.release'),
        value: _consoleOn,
        /// release/profile 构建下控制台输出已被编译期裁掉，开关置灰(onChanged 传 null)
        /// Console output is compiled out of release/profile builds, so the switch is
        /// disabled there (onChanged: null)
        onChanged: kConsoleAvailable
            ? (isOn) {
                _logger?.setConsoleEnable(isOn);
                setState(() => _consoleOn = isOn);
                showToast(
                    context, tr(isOn ? 'toast.console.on' : 'toast.console.off'));
              }
            : null,
      ),
      _switchRow(
        icon: Icons.power_settings_new,
        tint: const Color(0xFF34C759),
        title: tr('home.config.enable.title'),
        subtitle: tr('home.config.enable.subtitle'),
        value: _enableOn,
        onChanged: (isOn) {
          _logger?.setEnable(isOn);
          setState(() => _enableOn = isOn);
          showToast(context, tr(isOn ? 'toast.enable.on' : 'toast.enable.off'));
        },
      ),
      _switchRow(
        icon: Icons.nightlight_round,
        tint: kBrandColor,
        title: tr('home.config.background.title'),
        subtitle: 'shouldRemoveExpiredDataWhenEnterBackground',
        value: _backgroundCleanOn,
        onChanged: (isOn) {
          _logger?.shouldRemoveExpiredDataWhenEnterBackground(isOn);
          setState(() => _backgroundCleanOn = isOn);
        },
      ),
      _actionRow(
        icon: Icons.schedule,
        tint: kLevelColors[2],
        title: tr('home.config.age.title'),
        subtitle: tr('home.config.age.subtitle'),
        value: diskAgeText(_maxDiskAge),
        onTap: _pickDiskAge,
      ),
      _actionRow(
        icon: Icons.storage,
        tint: const Color(0xFFFF2D55),
        title: tr('home.config.size.title'),
        subtitle: tr('home.config.size.subtitle'),
        value: diskSizeText(_maxDiskSize),
        onTap: _pickDiskSize,
      ),
    ];
  }

  List<Widget> _perfRows() {
    return [
      _actionRow(
        icon: Icons.speed,
        tint: const Color(0xFF34C759),
        title: tr('home.perf.bench.title'),
        subtitle: tr('home.perf.bench.subtitle'),
        value: _benchRunning ? tr('home.perf.bench.running') : _perfResult,
        onTap: _runBenchmark,
      ),
      _actionRow(
        icon: Icons.memory,
        tint: const Color(0xFF30B0C7),
        title: tr('home.perf.thread.title'),
        subtitle: tr('home.perf.thread.subtitle'),
        value: _concurrentRunning ? tr('home.perf.thread.running') : null,
        onTap: _runConcurrentWrite,
      ),
    ];
  }

  List<Widget> _fileRows() {
    return [
      _actionRow(
        icon: Icons.folder,
        tint: kLevelColors[1],
        title: tr('home.file.browse.title'),
        subtitle: tr('home.file.browse.subtitle'),
        push: true,
        onTap: _openFileList,
      ),
      _actionRow(
        icon: Icons.history,
        tint: kLevelColors[2],
        title: tr('home.file.expire.title'),
        subtitle: 'removeExpireData',
        onTap: () {
          _logger?.removeExpireData();
          showToast(context, tr('toast.expire.done'));
          _refreshStatus();
        },
      ),
      _actionRow(
        icon: Icons.auto_delete,
        tint: const Color(0xFFFFCC00),
        title: tr('home.file.before.title'),
        subtitle: tr('home.file.before.subtitle'),
        onTap: () {
          _logger?.removeBeforeAllData();
          showToast(context, tr('toast.before.done'));
          _refreshStatus();
        },
      ),
      _actionRow(
        icon: Icons.delete,
        tint: kLevelColors[3],
        title: tr('home.file.all.title'),
        subtitle: 'removeAll',
        onTap: _confirmRemoveAll,
      ),
    ];
  }

  List<Widget> _infoRows() {
    return [
      _actionRow(
        icon: Icons.tag,
        tint: kBrandColor,
        title: 'loggerKey',
        subtitle: _loggerKey,
        onTap: () => _copyText(_loggerKey, tr('toast.key.copied')),
      ),
      _actionRow(
        icon: Icons.folder_open,
        tint: kLevelColors[0],
        title: tr('home.info.path.title'),
        subtitle: _diskCachePath,
        onTap: () => _copyText(_diskCachePath, tr('toast.path.copied')),
      ),
      _actionRow(
        icon: Icons.feedback,
        tint: kLevelColors[2],
        title: tr('home.info.error.title'),
        subtitle: tr('home.info.error.subtitle'),
        onTap: () {
          final desc = _logger?.errorDesc;
          _showAlert('errorDesc',
              (desc == null || desc.isEmpty) ? tr('alert.no.error') : desc);
        },
      ),
      _actionRow(
        icon: Icons.sync,
        tint: kLevelColors[3],
        title: tr('home.info.rebuild.title'),
        subtitle: tr('home.info.rebuild.subtitle'),
        onTap: _rebuildLogger,
      ),
    ];
  }

  Widget _section(String title, {String? footer, required List<Widget> rows}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: secondaryText(context))),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: cardBg(context), borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 58,
                      color: demoDividerColor(context)),
                rows[i],
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(footer,
                style: TextStyle(fontSize: 12, color: tertiaryText(context))),
          ),
      ],
    );
  }

  Widget _iconTile(IconData icon, Color tint) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
          color: tint, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color tint,
    required String title,
    String? subtitle,
    String? value,
    bool push = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _iconTile(icon, tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15, color: primaryText(context))),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: secondaryText(context))),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: secondaryText(context))),
              ),
            ],
            if (push) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 18, color: tertiaryText(context)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required Color tint,
    required String title,
    String? subtitle,
    required bool value,
    /// null 表示该开关在当前构建下不可用，Switch 自动变为置灰不可点
    /// null means the switch is unavailable in this build; Switch renders it greyed out
    ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      child: Row(
        children: [
          _iconTile(icon, tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        color: onChanged == null
                            ? secondaryText(context)
                            : primaryText(context))),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: secondaryText(context))),
                ],
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Future<T?> _showOptionsSheet<T>(
      String title, String subtitle, List<MapEntry<String, T>> options) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: secondaryText(context))),
                ],
              ),
            ),
            for (final option in options)
              ListTile(
                title: Text(option.key, textAlign: TextAlign.center),
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAlert(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: message.isEmpty
            ? null
            : SingleChildScrollView(
                child: SelectableText(message,
                    style: const TextStyle(fontSize: 14))),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('common.ok'))),
        ],
      ),
    );
  }
}

// ---------------- isolate 入口(必须是顶层函数) ----------------
// 注意: Isolate.run 的闭包不能在 State 的方法里创建——那样闭包上下文会把
// State/Element 一起捕获进去，导致 isolate 消息发送失败。
// 这里的顶层函数只捕获自己的参数(字符串/整数)，可以安全跨 isolate。

/// 后台 isolate 执行 10 万条写入基准测试，返回耗时(ms)
Future<int> _spawnBenchmark(String loggerKey) {
  return Isolate.run(() {
    final watch = Stopwatch()..start();
    for (var i = 1; i <= 100000; i++) {
      // 每条日志带序号，方便在查看器里核对写入顺序和完整性
      MXLogger.infoLog(loggerKey,
          '[${'$i'.padLeft(6, '0')}] This is a benchmark loooooooooooooooooooooooooooooog',
          name: 'benchmark', tag: 'perf');
    }
    return watch.elapsedMilliseconds;
  });
}

/// 启动一个后台 isolate 写入来源。isolate 之间共享的是 native 侧同一个
/// logger(通过 loggerKey 寻址)，与原生端多线程写同一个 logger 的场景等价。
Future<void> _spawnConcurrentWorker(
    String loggerKey, String runName, String tag, int total) {
  return Isolate.run(() {
    final random = Random();
    for (var i = 1; i <= total; i++) {
      final seq = '$i'.padLeft(5, '0');
      String msg;
      if (i % 100 == 0) {
        // 混入长消息，覆盖 mmap 扩容/跨页写入等边界
        msg = '#$seq $tag long message: ${'payload-' * 75}';
      } else {
        msg = '#$seq $tag concurrent write';
      }
      MXLogger.infoLog(loggerKey, msg, name: runName, tag: tag);
      // 随机让出 CPU，拉长并发重叠窗口，让调度交错更接近真实
      if (i % 50 == 0) sleep(Duration(microseconds: random.nextInt(500)));
    }
  });
}

/// 后台 isolate 解析日志文件，收集指定 runName 各来源的序号列表
Future<({int total, Map<String, List<int>> seqs})> _parseRunRecords(
    String path, String runName) {
  return Isolate.run(() {
    final records = MXLogger.selectLogmsg(
        diskcacheFilePath: path, cryptKey: kDemoCryptKey, iv: kDemoIV);
    // 按 tag 收集本轮日志的序号(保持文件中的先后顺序)
    final seqs = <String, List<int>>{};
    for (final record in records) {
      if (record['name']?.toString() != runName) continue;
      final msg = record['msg']?.toString() ?? '';
      final match = RegExp(r'^#(\d+)').firstMatch(msg);
      if (match == null) continue;
      final tag = record['tag']?.toString() ?? '';
      seqs.putIfAbsent(tag, () => <int>[]).add(int.parse(match.group(1)!));
    }
    return (total: records.length, seqs: seqs);
  });
}
