import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile channel and FFI use the checkout Core', (tester) async {
    const expected = String.fromEnvironment('MXLOGGER_EXPECTED_CORE_VERSION');
    expect(expected, isNotEmpty, reason: 'CI must supply the checkout version');
    expect(MXLogger.coreVersion(), expected);
    final ns = 'com.mxlogger.mobile.${DateTime.now().microsecondsSinceEpoch}';
    final logger = await MXLogger.initialize(nameSpace: ns);
    final directory = Directory(logger.diskcachePath);
    try {
      expect(directory.existsSync(), isTrue);
      expect(directory.path, contains(ns));
      expect(logger.enable, isTrue);
      expect(logger.info('mobile 中文', name: 'channel', tag: 'ffi'), 0);
      final path = '${directory.path}/${logger.logFiles.single.name}';
      expect(
        MXLogger.selectLogmsg(diskcacheFilePath: path).single['msg'],
        'mobile 中文',
      );
      // The legacy directory-level API is a documented placeholder on mobile.
      expect(MXLogger.selectLogfiles(directory: directory.path), isEmpty);
    } finally {
      MXLogger.destroy(nameSpace: ns);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    }
  });

  testWidgets('mobile encryption, token writes, cleanup and destruction', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('mxlogger_mobile_api_');
    const ns = 'com.mxlogger.mobile.encrypted';
    const key = 'abcdefg123456789';
    const iv = '0123456789abcdef';
    MXLogger? active;
    try {
      final logger = await MXLogger.initialize(
        nameSpace: ns,
        directory: root.path,
        fileHeader: 'header',
        cryptKey: key,
        iv: iv,
      );
      active = logger;
      expect(logger.debug('debug'), 0);
      expect(logger.info('info'), 0);
      expect(logger.warn('warn'), 0);
      expect(logger.error('error'), 0);
      expect(logger.fatal('fatal'), 0);
      MXLogger.infoLog(logger.loggerToken!, 'token');
      final path = '${logger.diskcachePath}/${logger.logFiles.single.name}';
      List<Map<String, dynamic>> read() =>
          MXLogger.selectLogmsg(diskcacheFilePath: path, cryptKey: key, iv: iv);
      expect(read().map((r) => r['msg']), [
        'token',
        'fatal',
        'error',
        'warn',
        'info',
        'debug',
        'header',
      ]);
      expect(
        MXLogger.selectLogmsg(
          diskcacheFilePath: path,
          cryptKey: 'wrong',
        ).every((r) => r['error_code'] == '1'),
        isTrue,
      );
      logger.setEnable(false);
      expect(logger.info('disabled'), 0);
      logger.setEnable(true);
      logger.setLevel(3);
      expect(logger.info('filtered'), 0);
      expect(logger.error('stored'), 0);
      expect(read(), hasLength(8));
      final expired = File('${logger.diskcachePath}/expired.mx');
      expired.writeAsStringSync('old');
      expired.setLastModifiedSync(DateTime(2000));
      logger.setMaxDiskAge(60);
      logger.shouldRemoveExpiredDataWhenEnterBackground(false);
      logger.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(expired.existsSync(), isTrue);
      logger.shouldRemoveExpiredDataWhenEnterBackground(true);
      logger.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(expired.existsSync(), isFalse);
      logger.removeBeforeAllData();
      logger.removeAll();
      expect(File(path).existsSync(), isTrue);
      expect(read(), hasLength(8));
      MXLogger.destroyWithLoggerToken(logger.loggerToken!);
      expect(logger.enable, isFalse);
      expect(logger.info('after destroy'), 0);
      active = await MXLogger.initialize(
        nameSpace: ns,
        directory: root.path,
        cryptKey: key,
        iv: iv,
      );
      expect(active.info('reopened'), 0);
      expect(read(), hasLength(9));
    } finally {
      if (active?.loggerToken != null) {
        MXLogger.destroyWithLoggerToken(active!.loggerToken!);
      }
      root.deleteSync(recursive: true);
    }
  });
}
