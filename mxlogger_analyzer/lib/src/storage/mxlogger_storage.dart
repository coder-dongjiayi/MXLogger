import 'package:shared_preferences/shared_preferences.dart';


class MXLoggerStorage{
  late SharedPreferences _sharedPreferences;
  static MXLoggerStorage instance = MXLoggerStorage._();

 final String  _aesKey = "com.dongjiayi.mxlogger.aeskey";
  final String _aesIv = "com.dongjiayi.mxlogger.aesiv";
  factory MXLoggerStorage() => instance;
  MXLoggerStorage._();
  Future<void> initialize() async{
    _sharedPreferences =  await SharedPreferences.getInstance();
  }

  String? get cryptKey => _sharedPreferences.getString(_aesKey);
  String? get cryptIv => _sharedPreferences.getString(_aesIv);

  Future<void> saveAES({String? cryptKey,String? iv}) async{

    if( cryptKey != null){
      await _sharedPreferences.setString(_aesKey, cryptKey);
    }
   if(iv != null){
     await _sharedPreferences.setString(_aesIv, iv);
   }
  }


}