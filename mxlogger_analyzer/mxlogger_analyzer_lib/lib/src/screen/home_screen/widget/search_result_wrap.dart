import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

class SearchResultWrap extends ConsumerWidget {
  const SearchResultWrap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResult = ref.watch(searchResultProvider);
    List<Widget> children = [];
    searchResult.forEach((key, value) {
      children.add(_item(ref, searchState: key, value: value));
    });
    return Wrap(
      spacing: 20,
      children: children,
    );
  }

  Widget _item(WidgetRef ref, {required String searchState, String? value}) {
    return GestureDetector(
      onDoubleTap: (){
        final map = ref.read(searchResultProvider);
        map.remove(searchState);
        ref.read(searchResultProvider.notifier).state = Map.of(map);
      },
      child: Container(
        decoration: BoxDecoration(
            color: MXTheme.sliderColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.only(left: 15, right: 15, top: 5, bottom: 5),
        child: RichText(
            text: TextSpan(children: [
              TextSpan(
                  text: "$searchState:",
                  style: TextStyle(color: MXTheme.info, fontSize: 16)),
              TextSpan(
                  text: value,
                  style: TextStyle(
                      color: MXTheme.white.withOpacity(0.7), fontSize: 16)),
            ])),
      ),
    );
  }
}
