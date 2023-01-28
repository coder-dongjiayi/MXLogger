import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
class LevelModel {
  final int level;
  final Color color;
  final String levelDesc;
  late  bool selected;
  LevelModel(
      {required this.level,
      required this.color,
      required this.levelDesc,
      required this.selected});
}

class LevelListState extends StateNotifier<List<LevelModel>> {
  LevelListState(List<LevelModel>? initialLevels) : super(initialLevels ?? []);

  void selected({required int level}){

   if(level == -1){
    state = state.map((e){
       e.selected = false;
         return e;
    }).toList();
   }else{
    state =  state.map((e){
     if(e.level == level){
      e.selected = !e.selected;
     }
     return e;
    }).toList();
   }

  }
}
