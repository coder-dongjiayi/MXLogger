
import 'package:flutter/cupertino.dart';
import 'package:mxlogger_analyzer/src/storage/mxlogger_storage.dart';

class SettingController extends ChangeNotifier{

  bool? _saveCrypt;

  bool get saveCrypt =>  _saveCrypt == null ? MXLoggerStorage.instance.cryptAlert : _saveCrypt!;

  void saveCryptState(bool state){
    _saveCrypt = state;
    MXLoggerStorage.instance.saveCryptAlert(state);
    notifyListeners();
  }
}