import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MenuItemModel{
  bool selected;
 final String title;
 final IconData iconData;
 final VoidCallback onTapCallback;
 MenuItemModel({this.selected = false,required this.title,required this.iconData,required this.onTapCallback});
}

class DebugMenuListState extends StateNotifier<List<MenuItemModel>>{
  DebugMenuListState(List<MenuItemModel>? initialMenus) : super(initialMenus ?? []);

  void selected({required int index}){

   state =  List.generate(state.length, (i){
      MenuItemModel model =  state[i];
      if(i == index){
        model.selected = !model.selected;
      }
      return model;
    });
  }
}