import 'dart:typed_data';


import 'log_serialize.dart';


class AnalyzerBinary{

  static void decode({required Uint8List binaryData}){
    int sizeof_uint32t = 4;
    Uint8List  actualUint8List = binaryData.sublist(0,4);

    ByteData actualData =  actualUint8List.buffer.asByteData();
    int totalSize =  actualData.getUint32(0,Endian.little);
    int begin = 4;
    while(begin <= totalSize){

      Uint8List itemData = binaryData.sublist(begin,begin + sizeof_uint32t);
      int itemSize = itemData.buffer.asByteData().getUint32(0,Endian.little);

      int start = begin + sizeof_uint32t;

      Uint8List buffer = binaryData.sublist(start,start+itemSize);
      LogSerialize logSerialize =   LogSerialize(buffer);
      print("name:${logSerialize.name}");
      print("name:${logSerialize.msg}");

      begin = begin + sizeof_uint32t + itemSize;

    }
  }
}