import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../data/side_menu_item_data.dart';

class SideMenuItemTitle extends StatelessWidget {
  const SideMenuItemTitle({
    Key? key,
    required this.data,
  }) : super(key: key);
  final SideMenuItemDataTitle data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: data.padding,
      child: _title(context: context),
    );
  }

  Widget _title({
    required BuildContext context,
  }) {
    final TextStyle? titleStyle =
        data.titleStyle ?? Theme.of(context).textTheme.bodyLarge;
    return AutoSizeText(
      data.title,
      style: titleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
