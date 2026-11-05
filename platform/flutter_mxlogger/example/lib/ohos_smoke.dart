// Device verification entry point: flutter build hap -t lib/ohos_smoke.dart
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

const _native = MethodChannel('mxlogger_ohos_verify');
const _key = 'abcdefgabcdefgob';
const _iv = 'abcdefgabcdefgcc';
const _marker = 'MXLOGGER_FLUTTER_OHOS ';

void _check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

List<Map<String, dynamic>> _read(MXLogger logger, bool encrypted) {
  return logger.logFiles.expand((file) {
    return MXLogger.selectLogmsg(
      diskcacheFilePath: '${logger.diskcachePath}/${file.name}',
      cryptKey: encrypted ? _key : null,
      iv: encrypted ? _iv : null,
    );
  }).toList();
}

Future<Map<String, Object?>> _verify() async {
  _check(Platform.operatingSystem == 'ohos', 'Expected HarmonyOS');
  _check(MXLogger.coreVersion() == '2.3.0', 'Core version');
  final modes = <Map<String, Object?>>[];
  for (final encrypted in [false, true]) {
    final ns = 'com.mxlogger.flutter.verify.${encrypted ? 'aes' : 'plain'}';
    final logger = await MXLogger.initialize(
      nameSpace: ns,
      cryptKey: encrypted ? _key : null,
      iv: encrypted ? _iv : null,
    );
    try {
      _check(logger.enable, 'Initialization failed');
      _check(
        logger.diskcachePath
            .replaceFirst(RegExp(r'/+$'), '')
            .endsWith('/com.mxlog.LoggerCache/$ns'),
        'Application sandbox directory',
      );
      final token = logger.loggerToken!;
      final previous = _read(logger, encrypted).length;
      final run = '$pid-${DateTime.now().microsecondsSinceEpoch}';
      for (var level = 0; level < 5; level++) {
        _check(
          logger.log(level, '$run:$level:中文🟩', name: 'dart', tag: 'ffi') == 0,
          'Dart FFI write at level $level',
        );
      }
      await _native.invokeMethod<void>('write', {
        'token': token,
        'message': '$run:arkts',
      });
      await Isolate.run(() {
        MXLogger.infoLog(token, '$run:isolate', name: 'dart', tag: 'isolate');
      });
      var rows = _read(logger, encrypted);
      final additions = rows
          .where((row) => '${row['msg']}'.startsWith(run))
          .toList();
      _check(
        rows.length == previous + 7 && additions.length == 7,
        'Five levels, ArkTS token write and Dart isolate write',
      );
      _check(
        additions.every((row) => row['error_code'] == '0'),
        'Decode errors',
      );
      final nativeCount = await _native.invokeMethod<int>('count', {
        'token': token,
      });
      _check(
        nativeCount == rows.length,
        'ArkTS reads Dart records from the same session',
      );
      logger.setLevel(3);
      logger.info('$run:filtered');
      logger.setEnable(false);
      logger.error('$run:disabled');
      logger.setEnable(true);
      logger.setLevel(0);
      _check(
        _read(logger, encrypted).length == rows.length,
        'Level and enable filtering',
      );
      logger.setMaxDiskAge(604800);
      logger.setMaxDiskSize(10485760);
      logger.removeExpireData();
      logger.didChangeAppLifecycleState(AppLifecycleState.paused);
      final directory = Directory(logger.diskcachePath).parent.path;
      final alias = MXLogger(
        nameSpace: ns,
        directory: directory,
        cryptKey: encrypted ? _key : null,
        iv: encrypted ? _iv : null,
      );
      _check(alias.loggerToken == token, 'Repeated initialize shares token');
      MXLogger.destroyWithLoggerToken(token);
      _check(
        !logger.enable && !alias.enable,
        'Destroy invalidates all Dart aliases',
      );
      final reopened = MXLogger(
        nameSpace: ns,
        directory: directory,
        cryptKey: encrypted ? _key : null,
        iv: encrypted ? _iv : null,
      );
      try {
        rows = _read(reopened, encrypted);
        _check(rows.length == previous + 7, 'Destroy/reopen persistence');
        modes.add({
          'encrypted': encrypted,
          'loggerToken': token,
          'previousCount': previous,
          'readBackCount': rows.length,
          'diskcachePath': reopened.diskcachePath,
          'nativeCount': nativeCount,
          'passed': true,
        });
      } finally {
        MXLogger.destroy(nameSpace: ns);
      }
    } finally {
      MXLogger.destroy(nameSpace: ns);
    }
  }
  return {
    'passed': true,
    'pid': pid,
    'coreVersion': MXLogger.coreVersion(),
    'modes': modes,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Map<String, Object?> report;
  try {
    report = await _verify();
  } catch (error, stack) {
    report = {
      'passed': false,
      'pid': pid,
      'error': '$error',
      'stack': '$stack',
    };
  }
  // A single machine-readable record for the HDC verification script.
  // ignore: avoid_print
  print('$_marker${jsonEncode(report)}');
  try {
    await _native.invokeMethod<void>('report', {'report': jsonEncode(report)});
  } catch (_) {
    // A standalone launch can still display the report without the test bridge.
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('MXLogger Flutter HarmonyOS')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            '${report['passed'] == true ? 'PASS' : 'FAIL'}\n'
            '${const JsonEncoder.withIndent('  ').convert(report)}',
          ),
        ),
      ),
    ),
  );
}
