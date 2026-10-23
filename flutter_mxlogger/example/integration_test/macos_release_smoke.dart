import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

/// Build this entrypoint with --release to verify FFI after AOT and symbol stripping.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final namespace =
      'com.mxlogger.macos.release.${DateTime.now().microsecondsSinceEpoch}';
  Directory? directory;
  try {
    const key = 'abcdefg123456789';
    const iv = '0123456789abcdef';
    final logger = await MXLogger.initialize(
      nameSpace: namespace,
      cryptKey: key,
      iv: iv,
      fileHeader: 'release header',
    );
    directory = Directory(logger.diskcachePath);
    if (!directory.path.contains('/MXLogger/$namespace')) {
      throw StateError('Unexpected macOS default directory: ${directory.path}');
    }
    if (logger.info('release 中文') != 0) {
      throw StateError('Release FFI write failed: ${logger.errorDesc}');
    }
    MXLogger.infoLog(logger.loggerToken!, 'release token');
    final file = '${directory.path}/${logger.logFiles.single.name}';
    final records = MXLogger.selectLogmsg(
      diskcacheFilePath: file,
      cryptKey: key,
      iv: iv,
    );
    if (records.length != 3 ||
        records[0]['msg'] != 'release token' ||
        records[1]['msg'] != 'release 中文' ||
        records[2]['msg'] != 'release header') {
      throw StateError('Release FFI round trip failed: $records');
    }
    MXLogger.destroy(nameSpace: namespace);
    directory.deleteSync(recursive: true);
    stdout.writeln('MXLOGGER_MACOS_RELEASE_SMOKE_OK');
    exit(0);
  } catch (error, stack) {
    MXLogger.destroy(nameSpace: namespace);
    if (directory != null && directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    stderr.writeln('$error\n$stack');
    exit(1);
  }
}
