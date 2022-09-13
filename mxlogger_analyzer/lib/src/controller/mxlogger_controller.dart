import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../page/lis_page/controller/request_controller.dart';
class MXLoggerController extends ChangeNotifier{

  RequestController? _requestController;
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;
  bool _dropVisibility = false;
  bool get dropVisibility => _dropVisibility;

  void dropTargetAction(bool end){
    _dropVisibility  = end;
     notifyListeners();
  }
  void setSelectedIndex(int index){
    if(index == _selectedIndex) return;
    _selectedIndex = index;
    notifyListeners();
  }

  void addRequestController(RequestController requestController){
    _requestController = requestController;
  }
  void deleteData(){
    _requestController?.refresh();
  }
  @override
  void dispose() {
    // TODO: implement dispose

    super.dispose();
  }
}