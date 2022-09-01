import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/analyzer_data/analyzer_database.dart';
import 'package:mxlogger_analyzer/src/page/lis_page/controller/request_controller.dart';
import '../../detail_page/view/async_future_loader.dart';
import '../log_model.dart';
import 'package:provider/provider.dart';

class MXTextFieldController extends ChangeNotifier {


  TextEditingController _searchController = TextEditingController();

  TextEditingController get searchController => _searchController;

   FocusNode focusNode = FocusNode();


  /// 点击回车键
  void entry(BuildContext context){
    String text =  _searchController.text.trim();
    RequestController requestController = context.read<RequestController>();
    requestController.updateKeyWord(text);


  }

  void searchChange(BuildContext context,String value){
    RequestController requestController = context.read<RequestController>();
    if(value == ""){
      requestController.updateKeyWord(value);
    }
  }



  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

}
