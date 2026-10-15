import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart'
    as fb;

/// Functional browser fixtures are kept outside the extension package.
/// flutter test --no-pub tool/generate_browser_fixture.dart
void main() {
  test(
    'Generate JSON, Unicode, pagination and multi-file browser fixtures',
    () {
      final directory = Directory('chrome_extension/tool/fixtures')
        ..createSync(recursive: true);
      for (final batch in [0, 1]) {
        final items = <Uint8List>[
          _record(
            MxBinaryParser.fileHeaderName,
            '',
            jsonEncode({'source': 'fixture$batch', '设备': '测试设备'}),
            0,
            1700000000000000,
          ),
          for (int index = batch * 40; index < batch * 40 + 60; index++)
            _record(
              index.isEven ? 'Auth' : 'Network',
              index.isEven ? 'auth, session' : 'network',
              jsonEncode({
                'index': index,
                'message': '用户登录成功 日本語ログ ひらがな カタカナ',
                'request': {
                  'ok': true,
                  'items': [
                    1,
                    null,
                    {'nested': '深层内容'},
                  ],
                },
                'marker': 'JSON_FIXTURE',
              }),
              index % 5,
              1700000000000001 + index * 123457,
            ),
        ];
        final bytes = BytesBuilder();
        void length(int value) => bytes.add(
          (ByteData(
            4,
          )..setUint32(0, value, Endian.little)).buffer.asUint8List(),
        );
        length(items.fold<int>(0, (sum, item) => sum + 4 + item.length));
        for (final item in items) {
          length(item.length);
          bytes.add(item);
        }
        File(
          '${directory.path}/fixture$batch.mx',
        ).writeAsBytesSync(bytes.takeBytes());
      }
    },
  );
}

Uint8List _record(
  String name,
  String tag,
  String msg,
  int level,
  int timestamp,
) {
  final builder = fb.Builder();
  final nameOffset = builder.writeString(name);
  final tagOffset = builder.writeString(tag);
  final msgOffset = builder.writeString(msg);
  final log = LogSerializeBuilder(builder)..begin();
  log.addNameOffset(nameOffset);
  log.addTagOffset(tagOffset);
  log.addMsgOffset(msgOffset);
  log.addLevel(level);
  log.addThreadId(1);
  log.addIsMainThread(1);
  log.addTimestamp(timestamp);
  builder.finish(log.finish());
  return builder.buffer;
}
