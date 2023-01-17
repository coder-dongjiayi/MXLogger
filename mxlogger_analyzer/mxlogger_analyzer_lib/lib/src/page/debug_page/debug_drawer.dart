import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
            DrawerItem(iconData: Icons.cleaning_services_outlined,title: "清空日志数据",onTap: () async{
             bool? flag =  await showAlert(context, ref);
             if(flag == true) {
               Navigator.of(context).pop();
             }
            }),

            DrawerItem(iconData: Icons.square_foot,title: "Show paint sizes",onTap: (){
              rendering.debugPaintSizeEnabled = !rendering.debugPaintSizeEnabled;
            },),
            DrawerItem(iconData: Icons.text_format,title: "Show paint baselines",onTap: (){
              rendering.debugPaintBaselinesEnabled = !rendering.debugPaintBaselinesEnabled;
            }),
            DrawerItem(iconData: Icons.border_style,title: "Show paint layer borders",onTap: (){
              rendering.debugPaintLayerBordersEnabled = !rendering.debugPaintLayerBordersEnabled;
            }),
            DrawerItem(iconData: Icons.palette,title: "Show repaint rainbow",onTap: (){
              rendering.debugRepaintRainbowEnabled = !rendering.debugRepaintRainbowEnabled;
            }),
            DrawerItem(iconData: Icons.text_rotate_up,title: "Show repaint text rainbow",onTap: (){
              rendering.debugRepaintTextRainbowEnabled = !rendering.debugRepaintTextRainbowEnabled;
            }),
            DrawerItem(iconData: Icons.circle_outlined,title: "Disable clip layers",onTap: (){
              rendering.debugDisableClipLayers = !rendering.debugDisableClipLayers;
            }),
            DrawerItem(iconData: Icons.rounded_corner,title: "Disable physical shape layers",onTap: (){
              rendering.debugDisablePhysicalShapeLayers = !rendering.debugDisablePhysicalShapeLayers;
            }),
            DrawerItem(iconData: Icons.opacity,title: "Disable opacity layers",onTap: (){
              rendering.debugDisableOpacityLayers = !rendering.debugDisableOpacityLayers;
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

