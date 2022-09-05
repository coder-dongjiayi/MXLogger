
import 'package:flutter/cupertino.dart';

import '../../../analyzer_data/analyzer_database.dart';
import '../../detail_page/view/async_future_loader.dart';
import '../log_model.dart';

class RequestController extends ChangeNotifier{

  List<LogModel> _dataSource = [];

  List<LogModel> get dataSource => _dataSource;

  AsyncController asyncController = AsyncController();

  int page = 1;

  String? _keyWord;


  String? get keyWord => _keyWord;


  void updateKeyWord(String keyword){
    String? _kw = keyword == "" ? null : keyword;
    if(_kw == _keyWord) return;
    _keyWord = _kw;
    asyncController.refresh();
  }
  Future<bool> refresh() async {
    page = 1;
    List<LogModel> source = await _searchData();
    _dataSource = source;
    notifyListeners();
    return true;
  }
  Future<bool> loadMore() async{
    page ++;
    List<LogModel> source = await _searchData();
    _dataSource.addAll(source);
    notifyListeners();
    return true;
  }


  Future<List<LogModel>> _searchData() async{

    List<Map<String, Object?>> list = await AnalyzerDatabase.selectData(page: page,keyWord: _keyWord);
    List<LogModel> source = _transformLogModel(list);
    return  source;
  }
  List<LogModel> _transformLogModel( List<Map<String, Object?>> list){
    List<LogModel> _source = [];
    list.forEach((element) {
      int level = element["level"] as int;
      int timestamp = element["timestamp"] as int;
      String? name = element["name"] as String?;
      String? tag = element["tag"] as String?;
      String? msg = element["msg"] as String?;
      int? threadId = element["threadId"] as int?;
      int? mainThreadId = element["isMainThread"] as int?;
      LogModel model = LogModel(
          name: name,
          tag: tag,
          msg: msg,
          threadId: threadId,
          isMainThread: mainThreadId,
          level: level,
          timestamp: timestamp);
      _source.add(model);
    });
    return _source;
  }
}