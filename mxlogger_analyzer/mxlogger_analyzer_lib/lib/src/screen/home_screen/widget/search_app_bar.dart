import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

class SearchAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const SearchAppBar({Key? key, this.onLevelCallback,this.onSearch}) : super(key: key);
  final ValueChanged<List<int>>? onLevelCallback;
  final VoidCallback? onSearch;

  Size get preferredSize => const Size.fromHeight(50);
  @override
  SearchAppBarState createState() => SearchAppBarState();
}

class SearchAppBarState extends ConsumerState<SearchAppBar> {
  @override
  Widget build(BuildContext context) {

    return Consumer(builder: (context, ref, _) {
      List<LevelModel> levelList = ref.watch(levelSearchProvider);
      return Container(
        margin: const EdgeInsets.only(top: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
               widget.onSearch?.call();
              },
              child: SizedBox(
                height: 30,
                child: Icon(Icons.search, size: 20, color: MXTheme.subText),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    children: List.generate(levelList.length, (index) {
                      LevelModel model = levelList[index];
                      return GestureDetector(
                        onTap: () {
                          ref
                              .read(levelSearchProvider.notifier)
                              .selected(level: model.level);
                          final selectedList = levelList
                              .where((element) => element.selected == true)
                              .map((e) => e.level)
                              .toList();
                          widget.onLevelCallback?.call(selectedList);
                        },
                        child: Builder(
                          builder: (context) {
                            return Container(
                              height: 30,
                              padding: const EdgeInsets.only(left: 5, right: 5),
                              margin: const EdgeInsets.only(right: 15),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                color: model.selected == true
                                    ? MXTheme.buttonColor
                                    : Colors.transparent,
                              ),
                              child: Text(model.levelDesc,
                                  style: TextStyle(
                                      color: model.color,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            );
                          },
                        ),
                      );
                    })))
          ],
        ),
      );
    });
  }
}
