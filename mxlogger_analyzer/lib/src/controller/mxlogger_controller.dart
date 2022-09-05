import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';

import '../page/lis_page/controller/request_controller.dart';
class MXLoggerController extends ChangeNotifier{

  RequestController? _requestController;

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