import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:flutter/rendering.dart' as rendering;
import 'package:mxlogger_analyzer_lib/src/component/mxlogger_text.dart';
class DebugDrawer extends ConsumerWidget {
  const DebugDrawer({Key? key,this.refreshCallback}) : super(key: key);
  final VoidCallback? refreshCallback;
  Future<bool?> showAlert(BuildContext context, WidgetRef ref) {
  return   showDialog<bool>(
        context: context,
        builder: (_context) {
          return CupertinoAlertDialog(
            title: Text("提示"),
            content: Text("你确定要清空数据库么"),
            actions: [
              CupertinoDialogAction(
                child: Text("取消"),
                onPressed: () {
                  Navigator.of(_context).pop(false);
                },
              ),
              CupertinoDialogAction(
                child: Text("清空"),
                onPressed: () {
                   ref.read(mxloggerRepository).deleteData();

                  ref.invalidate(logPagesProvider);
                  Navigator.of(_context).pop(true);
                },
              )
            ],
          );
        });
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
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 290,
      height: MediaQuery.of(context).size.height,
      color: MXTheme.sliderColor,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 20),
        child: Column(
          children: [
            DrawerItem(iconData: Icons.refresh,title: "刷新日志数据",onTap: (){
              refreshCallback?.call();
              Navigator.of(context).pop();
            }),

            DrawerItem(iconData: Icons.square_foot,title: "显示引导线",onTap: (){
              rendering.debugPaintSizeEnabled = !rendering.debugPaintSizeEnabled;
              _forceRepaint();
            },),
            DrawerItem(iconData: Icons.text_format,title: "显示基线",onTap: (){
              rendering.debugPaintBaselinesEnabled = !rendering.debugPaintBaselinesEnabled;
              _forceRepaint();
            }),
            DrawerItem(iconData: Icons.border_style,title: "显示边框",onTap: (){
              rendering.debugPaintLayerBordersEnabled = !rendering.debugPaintLayerBordersEnabled;
              _forceRepaint();
            }),
            DrawerItem(iconData: Icons.palette,title: "高亮重绘制内容",onTap: (){
              rendering.debugRepaintRainbowEnabled = !rendering.debugRepaintRainbowEnabled;
              _forceRepaint();
            }),
            DrawerItem(iconData: Icons.text_rotate_up,title: "开启文本背景色",onTap: (){
              rendering.debugRepaintTextRainbowEnabled = !rendering.debugRepaintTextRainbowEnabled;
              _forceRepaint();
            }),
            DrawerItem(iconData: Icons.circle_outlined,title: "禁用裁剪图层",onTap: (){
              rendering.debugDisableClipLayers = !rendering.debugDisableClipLayers;
              _forceRepaint();
            }),
            DrawerItem(iconData: Icons.rounded_corner,title: "禁用物理图层",onTap: (){
              rendering.debugDisablePhysicalShapeLayers = !rendering.debugDisablePhysicalShapeLayers;
              _forceRepaint();
            }),



          ],
        ),
      ),
    );
  }
}

class DrawerItem extends StatelessWidget {
  const DrawerItem({Key? key, required this.iconData, required this.title, required this.onTap}) : super(key: key);
  final IconData iconData;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: (){
      onTap.call();
    }, child: Container(
      margin: EdgeInsets.only(bottom: 20,left: 10),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
                color: MXTheme.itemBackground,
                borderRadius: BorderRadius.circular(8)
            ),

            child:  Icon(iconData,size: 35,color: MXTheme.white),
          ),
          SizedBox(width: 10),
          MXLoggerText(text: title,)
        ],
      ),
    ));
  }
}

