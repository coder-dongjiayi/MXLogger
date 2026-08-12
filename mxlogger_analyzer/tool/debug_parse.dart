import 'dart:io';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';

void main(List<String> args) {
  final Uint8List bytes =
      File("/Users/dongjiayi/Downloads/2026-07-07-15_log.mx").readAsBytesSync();
  final MxParseResult result = MxBinaryParser.parse(
    bytes,
    cryptKey: "abcde",
    iv: "abcdefg",
  );
  print("records=${result.records.length} errorCount=${result.errorCount}");
  print("fileHeader=${result.fileHeader}");
  for (final r in result.records) {
    print("[${r.level}] ${r.timestamp} ${r.name} ${r.tag}: ${r.msg}");
  }
}
