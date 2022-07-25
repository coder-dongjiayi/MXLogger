import 'dart:typed_data';
import 'dart:async';
import 'analyzer_database.dart';
import 'log_serialize.dart';

class AnalyzerBinary {
  static Future<void> loadData(
      {required Uint8List binaryData, String? cryptKey, String? iv}) {
    Completer<void> _completer = Completer();
    Future(() {
      _decode(binaryData: binaryData, cryptKey: cryptKey, iv: iv);
      _completer.complete();
    });
    return _completer.future;
  }

  static void _decode(
      {required Uint8List binaryData, String? cryptKey, String? iv}) {
    int sizeofUint32t = 4;

    int offsetLength = sizeofUint32t;

    Uint8List actualUint8List = binaryData.sublist(0, sizeofUint32t);

    ByteData actualData = actualUint8List.buffer.asByteData();
    int totalSize = actualData.getUint32(0, Endian.little);
    int begin = offsetLength;
    while (begin <= totalSize) {
      Uint8List itemData = binaryData.sublist(begin, begin + sizeofUint32t);
      int itemSize = itemData.buffer.asByteData().getUint32(0, Endian.little);

      int start = begin + sizeofUint32t;

      Uint8List buffer = binaryData.sublist(start, start + itemSize);
      LogSerialize logSerialize = LogSerialize(buffer);
      AnalyzerDatabase.insertData(
          name: logSerialize.name,
          tag: logSerialize.tag,
          msg: logSerialize.msg,
          level: logSerialize.level,
          threadId: logSerialize.threadId,
          isMainThread: logSerialize.isMainThread,
          timestamp: logSerialize.timestamp);

      begin = begin + sizeofUint32t + itemSize;
    }
  }
}
