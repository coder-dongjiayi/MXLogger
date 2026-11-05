// Validate the Demo's most recent complete benchmark using the existing analyzer.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main(List<String> args) {
  if (args.isEmpty || args.length > 2 || (args.length == 2 && args[1] != '--aes')) {
    stderr.writeln('usage: verify_ohos_benchmark.dart EXPORTED_DEMO_DIRECTORY [--aes]');
    exitCode = 2;
    return;
  }
  final encrypted = args.contains('--aes');
  final files = Directory(args.first).listSync(recursive: true).whereType<File>()
      .where((file) => file.path.endsWith('.mx')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final rows = <LogRecord>[];
  final sizes = <int>[];
  for (final file in files) {
    final bytes = file.readAsBytesSync();
    final parsed = MxBinaryParser.parse(bytes,
        cryptKey: encrypted ? 'abcdefgabcdefgob' : null,
        iv: encrypted ? 'abcdefgabcdefgcc' : null);
    check(parsed.errorCount == 0, 'decode errors: ${file.path}');
    final view = ByteData.sublistView(bytes);
    final end = 4 + view.getUint32(0, Endian.little);
    final frames = <int>[];
    for (var offset = 4; offset < end;) {
      final length = view.getUint32(offset, Endian.little);
      check(length > 0 && offset + 4 + length <= end, 'invalid frame boundary');
      frames.add(length);
      offset += 4 + length;
    }
    final headerCount = parsed.fileHeader == null ? 0 : 1;
    check(frames.length == parsed.records.length + headerCount, 'frame / record count mismatch');
    for (var i = 0; i < parsed.records.length; i++) {
      final row = parsed.records[i];
      if (row.name == 'benchmark' && row.tag == 'perf') {
        rows.add(row);
        sizes.add(frames[i + headerCount]);
      }
    }
  }
  const count = 100000;
  check(rows.length >= count, 'expected at least $count benchmark records, found ${rows.length}');
  final start = rows.length - count;
  for (var i = 0; i < count; i++) {
    final row = rows[start + i];
    final expected = '[${(i + 1).toString().padLeft(6, '0')}] This is a benchmark loooooooooooooooooooooooooooooog';
    check(row.msg == expected, 'message / sequence mismatch at ${i + 1}');
    check(utf8.encode(row.msg).length == 61, 'message must be 61 UTF-8 bytes');
    check(row.level == 1 && row.threadId > 0 && row.isMainThread == 0 && row.timestamp > 0,
        'benchmark metadata mismatch at ${i + 1}');
    check(sizes[start + i] == 152, 'serialized record must be 152 bytes');
  }
  stdout.writeln(jsonEncode({
    'passed': true, 'records': count, 'messageBytes': 61, 'serializedBytes': 152,
    'recordBytesWithLength': 156, 'totalBenchmarkBytes': count * 156, 'encrypted': encrypted,
  }));
}
