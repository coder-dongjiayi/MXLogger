import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/src/provider/advanced_filter_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/level_list_state.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

import 'package:mxlogger_analyzer_lib/src/theme/mx_theme.dart';

class SearchAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const SearchAppBar(
      {Key? key,
      this.onLevelCallback,
      this.onSearch,
      this.onAdvancedFilter,
      this.menuCallback})
      : super(key: key);
  final ValueChanged<List<int>>? onLevelCallback;
  final VoidCallback? onSearch;
  final VoidCallback? onAdvancedFilter;
  final VoidCallback? menuCallback;
  Size get preferredSize => const Size.fromHeight(40);
  @override
  SearchAppBarState createState() => SearchAppBarState();
}

class SearchAppBarState extends ConsumerState<SearchAppBar> {
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, _) {
      List<LevelModel> levelList = ref.watch(levelSearchProvider);
      return Container(
        margin: const EdgeInsets.only(top: 10),
        height: 40,
        child:  Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 10),
            analyzerPlatform == AnalyzerPlatform.desktop
                ? GestureDetector(
              onTap: () {
                widget.onSearch?.call();
              },
              child: Icon(Icons.search, size: 20, color: MXTheme.subText),
            )
                : const SizedBox(),
            const SizedBox(width: 12),
            _advancedFilterIcon(),
            const SizedBox(width: 6),
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
                    }))),
            _rightIcon()
          ],
        ),
      );
    });
  }

  /// 高级过滤器入口，有生效中的规则时图标高亮并带数量角标
  Widget _advancedFilterIcon() {
    final int enabledCount = ref.watch(advancedFilterProvider).enabledCount;
    final bool active = enabledCount > 0;
    return Tooltip(
      message: "高级过滤器(白名单/黑名单)",
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onAdvancedFilter?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded,
                    size: 20, color: active ? MXTheme.info : MXTheme.subText),
                if (active) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                        color: MXTheme.info.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text("$enabledCount",
                        style: TextStyle(color: MXTheme.info, fontSize: 11)),
                  )
                ]
              ],
            ),
          ),
        ),
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
          padding:
              const EdgeInsets.only(left: 20, right: 15, top: 5, bottom: 5),
          child: Icon(Icons.menu, color: MXTheme.subText),
        ),
      );
    }

    return const SizedBox();
  }
}
