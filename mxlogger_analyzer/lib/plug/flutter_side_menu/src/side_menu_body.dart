import 'package:flutter/material.dart';
import '../src/data/side_menu_data.dart';
import 'data/side_menu_item_data.dart';
import 'item/export.dart';

class SideMenuBody extends StatelessWidget {
  const SideMenuBody({
    Key? key,
    required this.minWidth,
    required this.isOpen,
    required this.data,
  }) : super(key: key);
  final double minWidth;
  final bool isOpen;
  final SideMenuData data;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (data.header != null) data.header!,
      if (data.customChild != null) Expanded(child: data.customChild!),
      if (data.items != null)
        Expanded(
          child: ListView.builder(
            controller: ScrollController(),
            itemCount: data.items!.length,
            itemBuilder: (context, index) {
              final SideMenuItemData item = data.items![index];
              if (item is SideMenuItemDataTile) {
                return SideMenuItemTile(
                  minWidth: minWidth,
                  isOpen: isOpen,
                  data: item,
                );
              } else if (item is SideMenuItemDataTitle) {
                return SideMenuItemTitle(
                  data: item,
                );
              } else if (item is SideMenuItemDataDivider) {
                return SideMenuItemDivider(
                  data: item,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      if (data.footer != null) data.footer!,
    ]);
  }
}
