import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

Future<void> showSearchDialog(BuildContext context,
    {ValueChanged<({String key, String? value})>? onCondition,EdgeInsetsGeometry? margin}) {
  return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return ProviderScope(
            parent: ProviderScope.containerOf(context),
            child: GestureDetector(
              onTap: (){
                Navigator.of(context).pop();
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: margin,
                  child: SearchDialog(
                    onCondition: onCondition,
                  ),
                ),
              ),
            ));
      });
}

final _textEditingControllerProvider = Provider<TextEditingController>((ref) {
  TextEditingController controller = TextEditingController();
  return controller;
});

enum _SearchState {
  keyword,
  tag,
  name,
  msg,
}

extension _SearchStateHit on _SearchState {
  String hintText() {
    bool desktop = analyzerPlatform == AnalyzerPlatform.desktop;
    if (index == 0) {
      return desktop == false ? "搜索关键词" : "搜索关键词 回车确定";
    }
    if (index == 1) {
      return "搜索多个tag，可使用,进行分割${desktop == true ? "，再按一次退格键还原" : ""}";
    }
    if (index == 2) {
      return "搜索name属性${desktop == true ? "，再按一次退格键还原" : ""}";
    }
    if (index == 3) {
      return "搜索msg内容${desktop == true ? "，再按一次退格键还原" : ""}";
    }
    return "";
  }
}

final _searchStateProvider = StateProvider.autoDispose<_SearchState>((ref) {
  ref.listenSelf((previous, next) {
    ref.read(_textEditingControllerProvider).text = "";
  });
  return _SearchState.keyword;
});

class SearchDialog extends ConsumerStatefulWidget {
  const SearchDialog({Key? key, this.onCondition}) : super(key: key);
  final ValueChanged<({String key, String? value})>? onCondition;
  @override
  SearchDialogState createState() => SearchDialogState();
}

class SearchDialogState extends ConsumerState<SearchDialog> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Container(
        alignment: Alignment.topCenter,
        margin: const EdgeInsets.only(top: 100),
        child: _search(),
      ),
    );
  }

  Widget _search() {
    return Container(
      decoration: BoxDecoration(
          color: MXTheme.themeColor,
          borderRadius: const BorderRadius.all(Radius.circular(30))),
      height: 50,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _leftIcon(),
          Expanded(child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(_searchStateProvider);
              return RawKeyboardListener(
                  onKey: (RawKeyEvent rawKey) {
                    if (rawKey.isKeyPressed(LogicalKeyboardKey.backspace) ==
                        true) {
                      if (state != _SearchState.keyword &&
                          ref
                                  .read(_textEditingControllerProvider)
                                  .text
                                  .isEmpty ==
                              true) {
                        ref.read(_searchStateProvider.notifier).state =
                            _SearchState.keyword;
                      }
                    }
                  },
                  focusNode: FocusNode(),
                  child: TextField(
                    autofocus: true,
                    controller: ref.read(_textEditingControllerProvider),
                    style: TextStyle(fontSize: 18, color: MXTheme.white),
                    onChanged: (String? keyword) {
                      if (keyword == "tag:") {
                        ref.read(_searchStateProvider.notifier).state =
                            _SearchState.tag;
                      } else if (keyword == "name:") {
                        ref.read(_searchStateProvider.notifier).state =
                            _SearchState.name;
                      } else if (keyword == "msg:") {
                        ref.read(_searchStateProvider.notifier).state =
                            _SearchState.msg;
                      }
                    },
                    onSubmitted: (String? keyword) {
                      if (keyword?.isNotEmpty == true) {
                        widget.onCondition
                            ?.call((key: state.name, value: keyword));
                        Navigator.of(context).pop();
                      }
                    },
                    decoration: InputDecoration(
                      isCollapsed: true,
                      hintText: state.hintText(),
                      hintStyle: TextStyle(color: MXTheme.text, fontSize: 18),
                      border: InputBorder.none,
                    ),
                  ));
            },
          )),
        ],
      ),
    );
  }

  Widget _leftIcon() {
    final state = ref.watch(_searchStateProvider);
    if (state != _SearchState.keyword) {
      return _tagIcon("${state.name}:");
    }
    return Container(
      margin: const EdgeInsets.only(left: 20,right: 20),
      child: Icon(Icons.search, size: 30, color: MXTheme.subText),
    );
  }

  Widget _tagIcon(String tag) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20),
      child: Text(
        tag,
        style: TextStyle(
            color: MXTheme.info, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

}
