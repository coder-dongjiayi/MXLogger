import 'dart:convert';

import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart';

import 'analyzer_database.dart';
import 'log_serialize.dart';
import 'package:mxlogger_analyzer_lib/src/dependencies/aes_crypt/aes_crypt_null_safe.dart';

const int AES_LENGTH = 16;
typedef AnalyzerProgressCallback = void Function(int total, int current,int index);
typedef AnalyzerValueChangedCallback = void Function(
    int succsss, int repeat, int field);

class AnalyzerBinary {
  static Future<void> loadBinaryData(
      {required List<Uint8List> binaryList,
        required String databasePath,
      String? cryptKey,
      String? iv,
      VoidCallback? onStartCallback,
      ValueChanged<String>? onErrorCallback,
      AnalyzerProgressCallback? onProgressCallback,
        AnalyzerValueChangedCallback? onEndCallback}) async {
    if(binaryList.isEmpty == true) return Future.value();
    /// 加载数据之前先关闭之前的数据库
    AnalyzerDatabase.db.dispose();

    onStartCallback?.call();

    ReceivePort mainPort = ReceivePort();
    await Isolate.spawn<SendPort>((SendPort port) {
      _runBinaryData(port);
    }, mainPort.sendPort);


    mainPort.listen((message) async {
      if (message is Map) {
        Map<String, dynamic> result = message as Map<String, dynamic>;
        int finish = result["finish"]; /// 1加载完成 0加载失败 2 加载中
        if (finish == 1) {
          /// 加载完数据再重新连接数据库
           AnalyzerDatabase.initDataBase(
              databasePath);
          int number = result["number"];
          int error = result["errorNumber"];
          int repeatNumber = result["repeatNumber"];
          onEndCallback?.call(number - repeatNumber, repeatNumber, error);
        } else if(finish == 2){

          int total = result["total"];
          int current = result["current"];
          int index = result["index"];
          onProgressCallback?.call(total,current,index);
        } else {
          String? errorMsg = result["errorMsg"];
          onErrorCallback?.call(errorMsg ?? "");
        }
      } else if (message is SendPort) {
        SendPort childPort = message;
        childPort.send({
          "binaryDataList": binaryList,
          "cryptKey": cryptKey,
          "iv": iv,
          "path": databasePath
        });
      }
    });
  }


  static void _runBinaryData(SendPort mainPort) async {
    ReceivePort childPort = ReceivePort();
    mainPort.send(childPort.sendPort);
    var result = await childPort.first;
    if ((result is Map) == false) return;

    List<Uint8List> _binaryDataList = result["binaryDataList"];
    String? cryptKey = result["cryptKey"];
    String? iv = result["iv"];
    String path = result["path"];
    int _errorNumber = 0;
    int _totalNumber = 0;

    int _repeatNumber = 0;
     AnalyzerDatabase.initDataBase(path);

     for(int i=0; i< _binaryDataList.length; i++){
       Uint8List binaryItem = _binaryDataList[i];
       await _decode(
           binaryData: binaryItem,
           cryptKey: cryptKey,
           iv: iv,
           errorCallback: (int errorNumber) {
             _errorNumber = errorNumber;
           },
           totalCallback: (int totalNumber) {
             _totalNumber = totalNumber;
           },
           onRepeatErrorCallback: () {
             _repeatNumber = _repeatNumber + 1;
           },
           onErrorDescCallback: (String errorMsg) {
             mainPort.send({"errorMsg": errorMsg, "finish": 0});
           },
           callback: (int total, int current,int index) {
             mainPort.send({"finish":2,"total":total,"current":current,"index":i});

           });

     }



    mainPort.send({
      "finish": 1,
      "number": _totalNumber,
      "errorNumber": _errorNumber,
      "repeatNumber": _repeatNumber
    });

    _repeatNumber = 0;
    AnalyzerDatabase.db.dispose();
    mainPort.send(null);
  }

  static Future<void> _decode(
      {required Uint8List binaryData,
      String? cryptKey,
      String? iv,
      ValueChanged<int>? errorCallback,
      ValueChanged<String>? onErrorDescCallback,
      VoidCallback? onRepeatErrorCallback,
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

    String? fileHeader;

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

        /// 第一条数据，并且name 为com.djy.mxlogger.fileHeader，则认定为fileHeader
        if (logSerialize.name == "com.djy.mxlogger.fileHeader" &&
            begin == sizeofUint32t) {
          fileHeader = logSerialize.msg;
        } else {
          await AnalyzerDatabase.insertData(
              name: logSerialize.name,
              fileHeader: fileHeader,
              tag: logSerialize.tag,
              msg: logSerialize.msg,
              level: logSerialize.level,
              threadId: logSerialize.threadId,
              isMainThread: logSerialize.isMainThread,
              errorCallback: (Map<String, dynamic> error) {
                /// 2067 为数据重复导入的错误 以timestamp为 唯一标识
                if (error["code"] != 2067) {
                  errorNumber = errorNumber + 1;
                  onErrorDescCallback?.call(error["message"]);
                } else {
                  onRepeatErrorCallback?.call();
                }
              },
              timestamp: logSerialize.timestamp);
          totalNumber = totalNumber + 1;
        }
      } catch (error) {
        errorNumber = errorNumber + 1;
        String msg = "二进制文件解析失败";
        if (error is SqliteException) {
          msg = error.message;
        }
        onErrorDescCallback?.call(msg);
      }

      callback?.call(totalSize, begin,0);
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
