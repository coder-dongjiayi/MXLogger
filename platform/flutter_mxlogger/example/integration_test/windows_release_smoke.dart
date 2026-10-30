import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

void _worker(List<String> args) {
  for (var i = 0; i < 50; ++i) {
    MXLogger.infoLog(args[0], '${args[1]}:$i');
  }
}

/// A relocated Debug/Release runner loads the bundled DLL with no environment
/// override. This tests packaging, the real default directory and secondary
/// isolates in addition to the direct-DLL unit tests.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final report = File(Platform.environment['MXLOGGER_SMOKE_REPORT']!);
  final namespace =
      'com.mxlogger.windows.${DateTime.now().microsecondsSinceEpoch}';
  Directory? directory;
  try {
    if (MXLogger.coreVersion() != '2.3.0') {
      throw StateError('Wrong Core version');
    }
    final logger = await MXLogger.initialize(
      nameSpace: namespace,
      fileHeader: 'Windows header',
      cryptKey: 'abcdefg123456789',
      iv: '0123456789abcdef',
    );
    directory = Directory(logger.diskcachePath);
    if (!directory.path.contains('MXLogger')) {
      throw StateError('Wrong default directory');
    }
    if (logger.info('Windows release 中文') != 0) {
      throw StateError('${logger.errorDesc}');
    }
    await Future.wait([
      compute(_worker, [logger.loggerToken!, 'first']),
      compute(_worker, [logger.loggerToken!, 'second']),
    ]);
    final file = '${logger.diskcachePath}/${logger.logFiles.single.name}';
    final rows = MXLogger.selectLogmsg(
      diskcacheFilePath: file,
      cryptKey: 'abcdefg123456789',
      iv: '0123456789abcdef',
    );
    if (rows.length != 102 || rows.map((r) => r['msg']).toSet().length != 102) {
      throw StateError(
        'Record count/isolate round trip failed: ${rows.length}',
      );
    }
    MXLogger.destroyWithLoggerToken(logger.loggerToken!);
    directory.deleteSync(recursive: true);
    report.parent.createSync(recursive: true);
    report.writeAsStringSync(
      jsonEncode({
        'passed': true,
        'coreVersion': MXLogger.coreVersion(),
        'records': rows.length,
        'executable': Platform.resolvedExecutable,
        'release': kReleaseMode,
      }),
    );
    exit(0);
  } catch (error, stack) {
    MXLogger.destroy(nameSpace: namespace);
    if (directory != null && directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
    report.parent.createSync(recursive: true);
    report.writeAsStringSync(
      jsonEncode({'passed': false, 'error': '$error', 'stack': '$stack'}),
    );
    exit(1);
  }
}
