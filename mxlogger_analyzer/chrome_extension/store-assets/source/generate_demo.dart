import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mxlogger_analyzer_lib/src/data/parser/log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/data/parser/mx_binary_parser.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/flat_buffers/flat_buffers.dart'
    as fb;

// Synthetic data only. Used to capture the real extension for its store listing.
void main() {
  final output = Directory.fromUri(Platform.script.resolve('fixtures/'))
    ..createSync(recursive: true);
  final base = DateTime.utc(2026, 10, 15, 1, 42).microsecondsSinceEpoch;
  final records = <Uint8List>[
    record(MxBinaryParser.fileHeaderName, '', jsonEncode({
      'app': 'MXLogger Demo',
      'version': '2.3.1',
      'environment': 'Sample data',
      'device': 'iPhone 15 Pro',
      'platform': 'iOS',
    }), 0, base),
  ];
  for (var batch = 0; batch < 8; batch++) {
    final events = <(String, String, int, String)>[
      ('App', 'startup', 1, 'App ready. Cold start completed in 412 ms.'),
      ('Auth', 'auth,session', 1,
          'Session restored for demo_user. Token expires in 3600 s.'),
      ('Network', 'network,GET', 0,
          'GET https://api.example.com/v1/profile'),
      ('Network', 'network,GET', 1, jsonEncode({
        'method': 'GET',
        'path': '/v1/profile',
        'status': 200,
        'duration_ms': 182,
        'response': {'id': 'demo_user', 'plan': 'free', 'active': true},
      })),
      ('Cache', 'cache', 0, 'Cache hit: user_profile. TTL remaining: 1723 s.'),
      ('Network', 'network,retry', 2,
          'Connection slow. Retrying POST /v1/orders in 1500 ms.'),
      ('Orders', 'network,checkout', 3, jsonEncode({
        'message': 'Request timeout',
        'method': 'POST',
        'url': 'https://api.example.com/v1/orders',
        'status': 504,
        'duration_ms': 15000,
        'request': {
          'id': 'req_demo_${batch + 1}',
          'items': [{'sku': 'demo-001', 'quantity': 2}],
          'retry': {'attempt': 2, 'max_attempts': 3},
        },
        'response': {
          'code': 'GATEWAY_TIMEOUT',
          'message': 'Upstream timeout after 15 seconds',
          'retryable': true,
        },
      })),
      ('Storage', 'database', 3,
          'Order insert failed: UNIQUE constraint failed: orders.id'),
      ('Rendering', 'ui', 0, 'HomeScreen rendered in 9 ms. No dropped frames.'),
      ('Auth', 'auth,session', 1, 'Access token refreshed successfully.'),
      ('Network', 'network,websocket', 1,
          'WebSocket connected. Heartbeat interval: 30 s.'),
      ('App', 'sync', batch == 2 ? 4 : 1,
          batch == 2
              ? 'Sync interrupted: unexpected null response in OrderService.'
              : 'Sync complete: 24 items updated. Local cache is up to date.'),
    ];
    for (var index = 0; index < events.length; index++) {
      final event = events[index];
      records.add(record(event.$1, event.$2, event.$4, event.$3,
          base + (batch * 60 + index * 3 + 1) * 1000000));
    }
  }
  File('${output.path}/demo-session.mx').writeAsBytesSync(pack(records));
  File('${output.path}/demo-encrypted.mx')
      .writeAsBytesSync(pack(records.map(encrypt).toList()));
  stdout.writeln('Generated ${records.length - 1} synthetic log records.');
}

Uint8List record(String name, String tag, String message, int level, int time) {
  final builder = fb.Builder();
  final n = builder.writeString(name);
  final t = builder.writeString(tag);
  final m = builder.writeString(message);
  final log = LogSerializeBuilder(builder)..begin();
  log.addNameOffset(n);
  log.addTagOffset(t);
  log.addMsgOffset(m);
  log.addLevel(level);
  log.addThreadId(name == 'Rendering' ? 1 : 104);
  log.addIsMainThread(name == 'Rendering' ? 1 : 0);
  log.addTimestamp(time);
  builder.finish(log.finish());
  return builder.buffer;
}

Uint8List pack(List<Uint8List> records) {
  final bytes = BytesBuilder();
  void length(int value) => bytes.add(
      (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List());
  length(records.fold(0, (total, row) => total + 4 + row.length));
  for (final row in records) {
    length(row.length);
    bytes.add(row);
  }
  return bytes.takeBytes();
}

Uint8List encrypt(Uint8List bytes) {
  final aes = AesCrypt();
  aes.aesSetKeys(Uint8List.fromList(utf8.encode('mxlogger-demo-01')),
      Uint8List.fromList(utf8.encode('demo-vector-0001')));
  aes.aesSetMode(AesMode.cfb);
  final padded = Uint8List(((bytes.length + 15) ~/ 16) * 16)
    ..setRange(0, bytes.length, bytes);
  return Uint8List.sublistView(aes.aesEncrypt(padded), 0, bytes.length);
}
