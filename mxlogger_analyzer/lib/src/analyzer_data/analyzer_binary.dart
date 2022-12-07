import 'dart:convert';

import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../storage/mxlogger_storage.dart';
import 'analyzer_database.dart';
import 'log_serialize.dart';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';

const int AES_LENGTH = 16;
typedef AnalyzerProgressCallback = void Function(int total, int current);
typedef AnalyValueChangedCallback = void Function(int succsss, int field);

class AnalyzerBinary {
  static void loadData(
      {required XFile file,
      String? cryptKey,
      String? iv,
      VoidCallback? onStartCallback,
      AnalyzerProgressCallback? onProgressCallback,
      AnalyValueChangedCallback? onEndCallback}) async {
    onStartCallback?.call();

    Uint8List? _binaryData = await file.readAsBytes();

    ReceivePort mainPort = ReceivePort();
    await Isolate.spawn<SendPort>((SendPort port) {
      _runBinaryData(port);
    }, mainPort.sendPort);

    mainPort.listen((message) {
      if (message is Map) {
        Map<String, dynamic> result = message as Map<String, dynamic>;
        int finish = result["finish"];
        if (finish == 1) {
          int number = result["number"];
          int error = result["errorNumber"];
          onEndCallback?.call(number, error);
        }
      } else if (message is SendPort) {
        SendPort childPort = message;
        childPort.send({
          "binaryData": _binaryData,
          "cryptKey": cryptKey,
          "iv": iv,
          "path": MXLoggerStorage.instance.databasePath
        });
      }
    });
  }

  static void _runBinaryData(SendPort mainPort) async {
    ReceivePort childPort = ReceivePort();
    mainPort.send(childPort.sendPort);
    var result = await childPort.first;
    if ((result is Map) == false) return;

    Uint8List _binaryData = result["binaryData"];
    String? cryptKey = result["cryptKey"];
    String? iv = result["iv"];
    String path = result["path"];
    int _errorNumber = 0;
    int _totalNumber = 0;

    await AnalyzerDatabase.initDataBase(path);
    await _decode(
        binaryData: _binaryData,
        cryptKey: cryptKey,
        iv: iv,
        errorCallback: (int errorNumber) {
          _errorNumber = errorNumber;
        },
        totalCallback: (int totalNumber) {
          _totalNumber = totalNumber;
        },
        callback: (int total, int current) {});

    mainPort.send(
        {"finish": 1, "number": _totalNumber, "errorNumber": _errorNumber});

    AnalyzerDatabase.db.dispose();
    mainPort.send(null);
  }

  static Future<void> _decode(
      {required Uint8List binaryData,
      String? cryptKey,
      String? iv,
      ValueChanged<int>? errorCallback,
      ValueChanged<int>? totalCallback,
      AnalyzerProgressCallback? callback}) async {
    int sizeofUint32t = 4;

    int offsetLength = sizeofUint32t;

    int errorNumber = 0;
    int totalNumber = 0;
    AesCrypt? crypt;
    if (cryptKey != null) {
      crypt = AesCrypt();
      Uint8List keyBytes = _replenishByte(cryptKey);
      Uint8List ivBytes = _replenishByte(iv ?? cryptKey);
      crypt.aesSetKeys(keyBytes, ivBytes);
      crypt.aesSetMode(AesMode.cfb);
    }

    Uint8List actualUint8List = binaryData.sublist(0, sizeofUint32t);

    ByteData actualData = actualUint8List.buffer.asByteData();
    int totalSize = actualData.getUint32(0, Endian.little);
    int begin = offsetLength;
    while (begin <= totalSize) {
      Uint8List itemData = binaryData.sublist(begin, begin + sizeofUint32t);
      int itemSize = itemData.buffer.asByteData().getUint32(0, Endian.little);

      int start = begin + sizeofUint32t;

      Uint8List buffer = binaryData.sublist(start, start + itemSize);
      try {
        if (crypt != null) {
          buffer = crypt.aesDecrypt(_replenishDataByte(buffer));
        }
        LogSerialize logSerialize = LogSerialize(buffer);

        await AnalyzerDatabase.insertData(
            name: logSerialize.name,
            tag: logSerialize.tag,
            msg: logSerialize.msg,
            level: logSerialize.level,
            threadId: logSerialize.threadId,
            isMainThread: logSerialize.isMainThread,
            errorCallback: (String error) {
              errorNumber = errorNumber + 1;
            },
            timestamp: logSerialize.timestamp);
        totalNumber = totalNumber + 1;
      } catch (error) {
        errorNumber = errorNumber + 1;
        debugPrint("二进制文件解析失败:$error");
      }

      callback?.call(totalSize, begin);
      begin = begin + sizeofUint32t + itemSize;
    }
    errorCallback?.call(errorNumber);
    totalCallback?.call(totalNumber);
  }

  /// 对 key 和 iv 进行补位
  static Uint8List _replenishByte(String input) {
    List<int> list = utf8.encode(input);
    Uint8List bytes = Uint8List.fromList(list);
    if (bytes.length == AES_LENGTH) return bytes;
    final uint8List = Uint8List(AES_LENGTH);
    int number = min(AES_LENGTH, bytes.length);
    for (int i = 0; i < number; i++) {
      uint8List[i] = bytes[i];
    }
    return uint8List;
  }

  /// 对data 进行补位
  static Uint8List _replenishDataByte(Uint8List buffer) {
    int bufferLen = buffer.length;
    if (bufferLen % AES_LENGTH == 0) return buffer;

    int length = (bufferLen / AES_LENGTH).ceil();
    final uint8List = Uint8List(length * AES_LENGTH);
    for (int i = 0; i < bufferLen; i++) {
      uint8List[i] = buffer[i];
    }
    return uint8List;
  }
}
