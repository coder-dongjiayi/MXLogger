import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'analyzer_database.dart';
import 'log_serialize.dart';

import 'package:aes_crypt_null_safe/aes_crypt_null_safe.dart';
const int AES_LENGTH = 16;


class AnalyzerBinary {
  static Future<void> loadData(
      {required Uint8List binaryData, String? cryptKey, String? iv}) {
    Completer<void> completer = Completer();
    Future(() {
      _decode(binaryData: binaryData, cryptKey: "mxloggerCryptKey", iv: "mxloggerCryptKey");
      completer.complete();
    });
    return completer.future;
  }
 /// 对 key 和 iv 进行补位
  static Uint8List _replenishByte(String input){
    List<int> list = utf8.encode(input);
    Uint8List bytes = Uint8List.fromList(list);
    if(bytes.length == AES_LENGTH)  return bytes;
    final uint8List = Uint8List(AES_LENGTH);
    int number = min(AES_LENGTH, bytes.length);
    for(int i = 0;i < number; i++){
      uint8List[i] = bytes[i];
    }
    return uint8List;
  }

  /// 对data 进行补位
  static Uint8List _replenishDataByte(Uint8List buffer){

  }
  static void _decode(
      {required Uint8List binaryData, String? cryptKey, String? iv}) {
    int sizeofUint32t = 4;

    int offsetLength = sizeofUint32t;

    AesCrypt? crypt;
    if(cryptKey != null){
      crypt =  AesCrypt();
      Uint8List keyBytes = _replenishByte(cryptKey);
      Uint8List ivBytes =_replenishByte( iv ?? cryptKey);
      crypt.aesSetKeys(keyBytes,ivBytes);
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

      try{
        if(crypt != null){

         buffer =   crypt.aesDecrypt(buffer);
        }
        LogSerialize logSerialize = LogSerialize(buffer);
        AnalyzerDatabase.insertData(
            name: logSerialize.name,
            tag: logSerialize.tag,
            msg: logSerialize.msg,
            level: logSerialize.level,
            threadId: logSerialize.threadId,
            isMainThread: logSerialize.isMainThread,
            timestamp: logSerialize.timestamp);
      }catch(error){
        print("解析出错:$error");
      }



      begin = begin + sizeofUint32t + itemSize;
    }
  }
}
