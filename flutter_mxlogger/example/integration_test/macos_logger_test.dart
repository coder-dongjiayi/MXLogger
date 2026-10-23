import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void _writeFromIsolate(List<String> arguments) {
  for (var index = 0; index < 50; index++) {
    MXLogger.infoLog(arguments[0], '${arguments[1]}:$index');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'macOS registers the channel and resolves the default directory',
    (tester) async {
      final namespace =
          'com.mxlogger.macos.default.'
          '${DateTime.now().microsecondsSinceEpoch}';
      final logger = await MXLogger.initialize(nameSpace: namespace);
      final directory = Directory(logger.diskcachePath);
      try {
        expect(directory.path, contains('/Application Support/'));
        expect(directory.path, contains('/MXLogger/$namespace'));
        expect(logger.info('macOS default directory 中文'), 0);
        final path = '${directory.path}/${logger.logFiles.single.name}';
        expect(
          MXLogger.selectLogmsg(diskcacheFilePath: path).single['msg'],
          'macOS default directory 中文',
        );
        expect(
          logger.logFiles.every((file) => file.name != '.mxlogger.lock'),
          isTrue,
        );
      } finally {
        MXLogger.destroy(nameSpace: namespace);
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isMacOS,
  );

  testWidgets(
    'macOS FFI supports encryption, tokens, cleanup and reopening',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'mxlogger_flutter_macos_',
      );
      const namespace = 'com.mxlogger.macos.custom';
      const key = 'abcdefg123456789';
      const iv = '0123456789abcdef';
      final logger = await MXLogger.initialize(
        nameSpace: namespace,
        directory: root.path,
        fileHeader: 'macOS header',
        cryptKey: key,
        iv: iv,
      );
      try {
        expect(logger.diskcachePath, startsWith(root.path));
        expect(logger.info('encrypted 中文', name: 'macos', tag: 'ffi'), 0);
        MXLogger.logLoggerToken(
          logger.loggerToken!,
          2,
          'from logger token',
          name: 'macos',
        );
        final path = '${logger.diskcachePath}/${logger.logFiles.single.name}';
        final records = MXLogger.selectLogmsg(
          diskcacheFilePath: path,
          cryptKey: key,
          iv: iv,
        );
        expect(records.map((record) => record['msg']), [
          'from logger token',
          'encrypted 中文',
          'macOS header',
        ]);

        final expired = File('${logger.diskcachePath}/expired.mx');
        logger.setMaxDiskAge(86400);
        for (final enabled in [false, true]) {
          expired.writeAsStringSync('expired');
          expired.setLastModifiedSync(DateTime(2000));
          logger.shouldRemoveExpiredDataWhenEnterBackground(enabled);
          logger.didChangeAppLifecycleState(AppLifecycleState.paused);
          logger.didChangeAppLifecycleState(AppLifecycleState.inactive);
          expect(expired.existsSync(), isTrue);
          logger.removeExpireData();
          expect(expired.existsSync(), isFalse);
        }

        MXLogger.destroyWithLoggerToken(logger.loggerToken!);
        expect(logger.enable, isFalse);
        final reopened = await MXLogger.initialize(
          nameSpace: namespace,
          directory: root.path,
          cryptKey: key,
          iv: iv,
        );
        expect(reopened.info('after reopening'), 0);
        final reopenedPath =
            '${reopened.diskcachePath}/${reopened.logFiles.single.name}';
        expect(
          MXLogger.selectLogmsg(
            diskcacheFilePath: reopenedPath,
            cryptKey: key,
            iv: iv,
          ),
          hasLength(4),
        );
      } finally {
        MXLogger.destroy(nameSpace: namespace, directory: root.path);
        root.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isMacOS,
  );

  testWidgets(
    'macOS FFI symbols are available to secondary isolates',
    (tester) async {
      final root = Directory.systemTemp.createTempSync(
        'mxlogger_macos_isolates_',
      );
      const namespace = 'com.mxlogger.macos.isolates';
      final logger = await MXLogger.initialize(
        nameSpace: namespace,
        directory: root.path,
      );
      try {
        await Future.wait([
          compute(_writeFromIsolate, [logger.loggerToken!, 'first']),
          compute(_writeFromIsolate, [logger.loggerToken!, 'second']),
        ]);
        final path = '${logger.diskcachePath}/${logger.logFiles.single.name}';
        final records = MXLogger.selectLogmsg(diskcacheFilePath: path);
        expect(records, hasLength(100));
        expect(records.map((record) => record['msg']).toSet(), hasLength(100));
      } finally {
        MXLogger.destroy(nameSpace: namespace, directory: root.path);
        root.deleteSync(recursive: true);
      }
    },
    skip: !Platform.isMacOS,
  );
}
