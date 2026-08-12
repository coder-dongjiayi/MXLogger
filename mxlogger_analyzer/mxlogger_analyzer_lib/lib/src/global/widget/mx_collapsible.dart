import 'package:flutter/material.dart';

/// 按高度收起/展开的容器（收起时高度为 0，子树**保持挂载**）。
///
/// 用 heightFactor 而非条件构建：手机端收起筛选区时，
/// 搜索框里的输入内容与焦点、各卡片的滚动位置都不会因收起而丢失。
class MXCollapsible extends StatelessWidget {
  const MXCollapsible({
    super.key,
    required this.collapsed,
    required this.child,
    this.duration = const Duration(milliseconds: 180),
  });

  final bool collapsed;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: collapsed ? 0 : 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (BuildContext context, double factor, Widget? child) {
        // 收起后不摘掉子树（height 0 + 裁剪），状态与焦点因此得以保留
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: factor,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
