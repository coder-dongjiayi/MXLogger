import 'dart:convert';
import 'dart:io';

import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_core.dart';

/// Native baseline for browser parity checks, including exact microseconds.
void main() {
  final result = MxBinaryParser.parse(
    File('web/samples/sample_plain.mx').readAsBytesSync(),
  );
  final encrypted = MxBinaryParser.parse(
    File('web/samples/sample_encrypted.mx').readAsBytesSync(),
    cryptKey: 'mxlogger123',
  );
  Map<String, Object?> snapshot(MxParseResult parsed) => {
    'fileHeader': parsed.fileHeader,
    'errorCount': parsed.errorCount,
    'records': [
      for (final record in parsed.records)
        {
          'name': record.name,
          'tag': record.tag,
          'msg': record.msg,
          'level': record.level,
          'threadId': record.threadId,
          'isMainThread': record.isMainThread,
          'timestamp': record.timestamp,
        },
    ],
  };
  final expected = snapshot(result);
  if (jsonEncode(expected) != jsonEncode(snapshot(encrypted))) {
    throw StateError('Plain and encrypted fixtures differ.');
  }
  File(
    'web/samples/expected.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(expected));
  stdout.writeln('Native baseline: ${result.records.length} matching records.');
}
