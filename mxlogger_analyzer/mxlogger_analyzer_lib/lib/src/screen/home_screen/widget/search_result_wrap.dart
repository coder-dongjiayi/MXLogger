import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:mxlogger_analyzer_lib/src/component/mx_hoverable.dart';
import 'package:mxlogger_analyzer_lib/src/provider/mxlogger_provider.dart';

class SearchResultWrap extends ConsumerWidget {
  const SearchResultWrap({Key? key, this.onChange}) : super(key: key);
  final ValueChanged<String>? onChange;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchResult = ref.watch(searchResultProvider);
    List<Widget> children = [];
    searchResult.forEach((key, value) {
      children.add(_item(ref, searchState: key, value: value));
    });
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }

  /// 一条生效中的搜索条件。
  ///
  /// 右侧常驻一个 × 用来移除；悬停时整条高亮、× 变亮，
  /// 保证"这东西能删"是看得见的。
  Widget _item(WidgetRef ref, {required String searchState, String? value}) {
    return MXHoverable(
      builder: (hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.only(left: 14, right: 5, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: MXTheme.sliderColor.withOpacity(hovered ? 0.6 : 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hovered ? MXTheme.info.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
                text: TextSpan(children: [
              TextSpan(
                  text: "$searchState:",
                  style: TextStyle(color: MXTheme.info, fontSize: 16)),
              TextSpan(
                  text: value,
                  style: TextStyle(
                      color: MXTheme.white.withOpacity(0.7), fontSize: 16)),
            ])),
            const SizedBox(width: 6),
            Tooltip(
              message: "移除该条件",
              child: MXHoverable(
                onTap: () => onChange?.call(searchState),
                builder: (closeHovered) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: closeHovered
                        ? MXTheme.white.withOpacity(0.16)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: closeHovered || hovered
                        ? MXTheme.white
                        : MXTheme.subText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
