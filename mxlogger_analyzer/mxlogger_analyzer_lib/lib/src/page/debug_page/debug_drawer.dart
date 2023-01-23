import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:mxlogger_analyzer_lib/src/component/mxlogger_text.dart';

import 'menu_list_state.dart';

final menuListProvider =
    StateNotifierProvider<DebugMenuListState, List<MenuItemModel>>((ref) {

    bool paintSizeEnabled =   rendering.debugPaintSizeEnabled;
    bool baselinesEnabled =  rendering.debugPaintBaselinesEnabled;
    bool bordersEnabled = rendering.debugPaintLayerBordersEnabled;
    bool rainbowEnabled = rendering.debugRepaintRainbowEnabled;
    bool textRainbowEnabled = rendering.debugRepaintTextRainbowEnabled;
    bool clipLayers = rendering.debugDisableClipLayers;
    bool physicalShape =  rendering.debugDisablePhysicalShapeLayers;

    return DebugMenuListState([
    MenuItemModel(selected: paintSizeEnabled, title: "显示引导线", iconData: Icons.square_foot,onTapCallback: (){
      rendering.debugPaintSizeEnabled = !rendering.debugPaintSizeEnabled;
    }),
    MenuItemModel(selected: baselinesEnabled, title: "显示基线", iconData: Icons.text_format,onTapCallback: (){
      rendering.debugPaintBaselinesEnabled = !rendering.debugPaintBaselinesEnabled;
    }),
    MenuItemModel(selected: bordersEnabled, title: "显示边框", iconData: Icons.border_style,onTapCallback: (){
      rendering.debugPaintLayerBordersEnabled = !rendering.debugPaintLayerBordersEnabled;
    }),
    MenuItemModel(selected: rainbowEnabled, title: "高亮重绘制内容", iconData: Icons.palette,onTapCallback: (){
      rendering.debugRepaintRainbowEnabled = !rendering.debugRepaintRainbowEnabled;
    }),
    MenuItemModel(
        selected: textRainbowEnabled, title: "开启文本背景色", iconData: Icons.text_rotate_up,onTapCallback: (){
      rendering.debugRepaintTextRainbowEnabled = !rendering.debugRepaintTextRainbowEnabled;
    }),
    MenuItemModel(
        selected: clipLayers, title: "禁用裁剪图层", iconData: Icons.circle_outlined,onTapCallback: (){
      rendering.debugDisableClipLayers = !rendering.debugDisableClipLayers;
    }),
    MenuItemModel(
        selected: physicalShape, title: "禁用物理图层", iconData: Icons.rounded_corner,onTapCallback: (){
      rendering.debugDisablePhysicalShapeLayers = !rendering.debugDisablePhysicalShapeLayers;
    })
  ]);
});

class DebugDrawer extends ConsumerWidget {
  const DebugDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 290,
      height: MediaQuery.of(context).size.height,
      color: MXTheme.sliderColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20),
        child: Builder(builder: (context) {
          List<MenuItemModel> list = ref.watch(menuListProvider);

          return Column(
            children: List.generate(list.length, (index) {
              MenuItemModel model = list[index];
              return DrawerItem(
                  selected: model.selected,
                  iconData: model.iconData,
                  title: model.title,
                  onTap: () {
                          ref.read(menuListProvider.notifier).selected(index: index);
                          model.onTapCallback.call();
                             _forceRepaint();
                  });
            }),
          );
        }),

      ),
    );
  }

  Future<void> _forceRepaint() {
    late RenderObjectVisitor visitor;
    visitor = (RenderObject child) {
      child.markNeedsPaint();
      child.visitChildren(visitor);
    };

    RendererBinding.instance.renderView.visitChildren(visitor);
    return RendererBinding.instance.endOfFrame;
  }
}

class DrawerItem extends StatelessWidget {
  const DrawerItem({
    Key? key,
    required this.iconData,
    required this.title,
    required this.onTap,
    this.selected = false,
  }) : super(key: key);
  final IconData iconData;
  final String title;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: () {
          onTap.call();
        },
        child: Container(
          margin: EdgeInsets.only(bottom: 20, left: 10, right: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: MXTheme.itemBackground,
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(iconData, size: 35, color: MXTheme.white),
              ),
              SizedBox(width: 10),
              Expanded(
                child: MXLoggerText(
                  text: title,
                ),
              ),
              Checkbox(
                  checkColor: MXTheme.themeColor,

                  fillColor:
                      MaterialStateColor.resolveWith((states) => Colors.white),
                  value: selected,
                  onChanged: (value) {
                    onTap.call();
                  })
            ],
          ),
        ));
  }
}
