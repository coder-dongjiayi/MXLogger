import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


class MXLoggerStorage{
  late SharedPreferences _sharedPreferences;
  static MXLoggerStorage instance = MXLoggerStorage._();
  static late String  _databasePath;

  String get databasePath => _databasePath;
  final String  _aesKey = "com.dongjiayi.mxlogger.aeskey";
  final String _aesIv = "com.dongjiayi.mxlogger.aesiv";
  final String _cryptAlertKey = "com.dongjiayi.mxlogger.cryptAlert";
  factory MXLoggerStorage() => instance;
  MXLoggerStorage._();
  Future<void> initialize() async{
    _sharedPreferences =  await SharedPreferences.getInstance();
    Directory directory =  await getApplicationDocumentsDirectory();
    _databasePath = directory.path;
  }

  String? get cryptKey => _sharedPreferences.getString(_aesKey) == "" ? null :  _sharedPreferences.getString(_aesKey);
  String? get cryptIv => _sharedPreferences.getString(_aesIv) == "" ? null : _sharedPreferences.getString(_aesIv);
  bool get cryptAlert => _sharedPreferences.getBool(_cryptAlertKey) ?? false;
 Future<void> saveCryptAlert(bool? state) async{
   await _sharedPreferences.setBool(_cryptAlertKey, state ?? false);
 }

  Future<void> saveAES({String? cryptKey,String? iv}) async{

    if( cryptKey != null){
      await _sharedPreferences.setString(_aesKey, cryptKey);
    }
   if(iv != null){
     await _sharedPreferences.setString(_aesIv, iv);
   }
  }


}