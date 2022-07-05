import 'dart:typed_data';


import 'log_serialize.dart';


class AnalyzerBinary{

  static void decode({required Uint8List binaryData, String? cryptKey,String? iv}){
    int sizeofUint32t = 4;

    int offsetLength =  sizeofUint32t;


    Uint8List  actualUint8List = binaryData.sublist(0,4);

    ByteData actualData =  actualUint8List.buffer.asByteData();
    int totalSize =  actualData.getUint32(0,Endian.little);
    int begin = offsetLength;
    while(begin <= totalSize){

      Uint8List itemData = binaryData.sublist(begin,begin + sizeofUint32t);
      int itemSize = itemData.buffer.asByteData().getUint32(0,Endian.little);

      int start = begin + sizeofUint32t;

      Uint8List buffer = binaryData.sublist(start,start+itemSize);
      LogSerialize logSerialize =   LogSerialize(buffer);

      print("name:${logSerialize.name}");
      print("name:${logSerialize.msg}");

      begin = begin + sizeofUint32t + itemSize;

    }
  }
}