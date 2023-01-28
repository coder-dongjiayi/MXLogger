import 'package:flutter/material.dart';
import '../data/side_menu_item_data.dart';

class SideMenuItemDivider extends StatelessWidget {
  const SideMenuItemDivider({
    Key? key,
    required this.data,
  }) : super(key: key);
  final SideMenuItemDataDivider data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: data.padding,
      child: data.divider,
    );
  }
}
