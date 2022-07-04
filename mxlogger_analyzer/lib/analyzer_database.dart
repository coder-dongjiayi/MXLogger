import 'dart:io';

import 'package:sqflite/sqflite.dart' as SQLite;
import 'package:path_provider/path_provider.dart';
class AnalyzerDatabase{


  static void initDataBase() async{
    Directory directory = await getApplicationDocumentsDirectory();
    String dataBasePath = directory.path + "/analyzer.db";
    // bool isExit = await SQLite.databaseExists(dataBasePath);
    // if(isExit == false){
    //
    // }
  }

}