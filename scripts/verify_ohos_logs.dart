// Uses the existing analyzer parser directly; no alternate .mx decoder.
import 'dart:convert';
import 'dart:io';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: verify_ohos_logs.dart DEVICE_REPORT_JSON');
    exitCode = 2;
    return;
  }
  final report = jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final directory = report['exportDirectory'] as String;
  final launches = report['launches'] as List<dynamic>;
  final latest = launches.last as List<dynamic>;
  final results = <Map<String, Object>>[];
  for (final encrypted in [false, true]) {
    final expected = latest.cast<Map<String, dynamic>>()
        .singleWhere((item) => item['encrypted'] == encrypted);
    final namespace = encrypted ? 'poc_encrypted' : 'poc_plain';
    final files = Directory(directory).listSync(recursive: true).whereType<File>()
        .where((file) => file.path.split(Platform.pathSeparator).contains(namespace)
            && file.path.endsWith('.mx')).toList();
    check(files.isNotEmpty, 'no $namespace .mx files exported');
    final records = <LogRecord>[];
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final result = MxBinaryParser.parse(bytes,
          cryptKey: encrypted ? 'poc-test-key-1234' : null,
          iv: encrypted ? 'poc-test-iv--1234' : null);
      check(result.errorCount == 0, 'decode errors in ${file.path}');
      records.addAll(result.records);
      if (encrypted) {
        final wrong = MxBinaryParser.parse(bytes, cryptKey: 'wrong-poc-key');
        check(wrong.records.isEmpty && wrong.errorCount > 0,
            'wrong key unexpectedly decoded ${file.path}');
      }
    }
    check(records.length == expected['readBackCount'], '$namespace count mismatch');
    check(records.map((r) => r.msg).toSet().length == records.length,
        '$namespace contains duplicated messages');
    check(records.every((r) => r.name == 'ohos_poc' && r.level == 1 &&
        r.threadId > 0 && r.timestamp > 0 && r.msg.contains('中文 ✅')),
        '$namespace metadata/UTF-8 mismatch');
    check(records.where((r) => r.tag == 'ffi').length * 2 == records.length,
        '$namespace FFI/native record balance mismatch');
    results.add({'namespace': namespace, 'records': records.length, 'passed': true});
  }
  stdout.writeln(jsonEncode({'passed': true, 'parser': 'MxBinaryParser', 'results': results}));
}
