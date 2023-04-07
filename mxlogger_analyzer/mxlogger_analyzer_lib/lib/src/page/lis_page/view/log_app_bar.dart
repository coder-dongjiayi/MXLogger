import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

import '../../../theme/mx_theme.dart';

class LogAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const LogAppBar({Key? key, this.menuCallback}) : super(key: key);
  final VoidCallback? menuCallback;
  @override
  // TODO: implement preferredSize
  Size get preferredSize => const Size.fromHeight(80);
  @override
  LogAppBarState createState() => LogAppBarState();
}

class LogAppBarState extends ConsumerState<LogAppBar> {
  FocusNode _focusNode = FocusNode();
  List<String?> _conditionList = [null,"tag:","name:","msg:"];
  int _conditionIndex = 0;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Container(
            padding: const EdgeInsets.only(top: 10, left: 10),
            child: Column(
              children: [_search(), _level()],
            )));
  }

  Widget _level() {
    return SizedBox(
      height: 35,
      child: Consumer(builder: (context, ref, _) {
        List<LevelModel> levelList = ref.watch(levelSearchProvider);
        return ListView(
            scrollDirection: Axis.horizontal,
            children: List.generate(levelList.length, (index) {
              LevelModel model = levelList[index];
              return _button(model);
            }));
      }),
    );
  }

  Widget _button(LevelModel model) {
    return GestureDetector(
      onTap: () {
        ref.read(levelSearchProvider.notifier).selected(level: model.level);
      },
      child: Builder(
        builder: (context) {
          return Container(
            padding: const EdgeInsets.only(left: 7, right: 7),
            margin: const EdgeInsets.only(right: 10, top: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: model.selected == true
                  ? MXTheme.buttonColor
                  : Colors.transparent,
            ),
            child: Text(model.levelDesc,
                style: TextStyle(color: model.color, fontSize: 15)),
          );
        },
      ),
    );
  }

  void _nextCondition(){
    _conditionIndex = _conditionIndex + 1;
    if(_conditionIndex == _conditionList.length){
      _conditionIndex = 0;
    }
    ref.read(conditionProvider.notifier).state = _conditionList[_conditionIndex];
    _focusNode.requestFocus();
  }
  Widget _search() {
    String? condition = ref.watch(conditionProvider);
    String? hitText = ref.watch(searchHitTextProvider);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: MXTheme.themeColor,
          borderRadius: BorderRadius.all(Radius.circular(5))),
      height: 30,
      child: Row(
        children: [
          Visibility(
            visible: condition != null,
            replacement: GestureDetector(
              onTap: (){
                _nextCondition();
              },
              child: Container(
                height: 30,
                padding: EdgeInsets.only(left: 10,right: 10),
                child: Icon(Icons.search, size: 20, color: MXTheme.subText),
              ),
            ),
            child: GestureDetector(
              onTap: (){
                _nextCondition();
              },
              child: Container(
                margin: EdgeInsets.only(left: 10, right: 10),
                child: Text(
                  "$condition",
                  style: TextStyle(color: MXTheme.info, fontSize: 16,fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
              child: RawKeyboardListener(
                  onKey: (RawKeyEvent rawKey) {
                    if (rawKey.isKeyPressed(LogicalKeyboardKey.backspace) ==
                        true) {
                      if (ref.read(conditionProvider) != null &&
                          ref
                              .read(textEditingControllerProvider)
                              .text
                              .isEmpty) {
                        ref.read(conditionProvider.notifier).state = null;
                      }
                    }
                  },
                  focusNode: FocusNode(),
                  child: TextField(
                    focusNode: _focusNode,
                    autofocus: analyzerPlatform == AnalyzerPlatform.desktop
                        ? true
                        : false,
                    controller: ref.read(textEditingControllerProvider),
                    style: TextStyle(fontSize: 16, color: MXTheme.white),
                    onChanged: (String? keyword) {
                      if (keyword?.isEmpty == true) {
                        ref.read(keywordSearchProvider.notifier).state = null;
                      }
                      String? condition = ref.read(conditionProvider);
                      if (condition == null) {
                        ref.read(searchTextChangeProvider.notifier).state =
                            keyword;
                      }
                    },
                    onSubmitted: (String? keyword) {
                      ref.read(keywordSearchProvider.notifier).state = keyword;
                      if(keyword?.isNotEmpty == true){
                        ref.read(propertySearchProvider.notifier).state = ref.read(conditionProvider);
                      }

                      _focusNode.requestFocus();
                    },
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: hitText,
                      hintStyle: TextStyle(color: MXTheme.text, fontSize: 16),
                      border: InputBorder.none,
                    ),
                  ))),
          _rightIcon()
        ],
      ),
    );
  }

  Widget _rightIcon() {
    if (analyzerPlatform == AnalyzerPlatform.package) {
      return GestureDetector(
        onTap: () {
          widget.menuCallback?.call();
        },
        child: Container(
          color: Colors.transparent,
          padding: EdgeInsets.only(left: 20, right: 15, top: 5, bottom: 5),
          child: Icon(Icons.menu, color: MXTheme.subText),
        ),
      );
    }

    return SizedBox();
    // return Container(
    //   margin: EdgeInsets.only(left: 10, right: 10),
    //   child: Icon(Icons.add,color: Colors.white,),
    // );
  }
}
