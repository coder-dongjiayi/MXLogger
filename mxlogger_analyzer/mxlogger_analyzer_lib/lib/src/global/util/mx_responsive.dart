import 'package:flutter/material.dart';

/// 移动端适配（对齐设计稿 MXLogger.dc.html 的 `@media` 断点）。
///
/// 设计稿用两级断点：
/// - `max-width:720px`：手机/窄窗口——留白收窄、按钮加大到可点尺寸、
///   等级 chips 改横向滚动、弹窗全屏、Key/IV 与时间输入改竖向铺满。
/// - `max-width:480px`：超窄——日志时间戳隐藏日期只留时分秒、Header 网格单列。
///
/// 桌面壳与嵌入手机 app 共用同一套 UI，故按可用宽度判定而非 Platform。
class MXBreakpoints {
  MXBreakpoints._();

  /// 设计稿 `@media (max-width:720px)`
  static const double mobile = 720;

  /// 设计稿 `@media (max-width:480px)`
  static const double narrow = 480;
}

extension MXResponsive on BuildContext {
  /// 手机/窄窗口布局（≤720）
  bool get isMobileLayout => MediaQuery.sizeOf(this).width <= MXBreakpoints.mobile;

  /// 超窄布局（≤480），在 [isMobileLayout] 基础上进一步精简
  bool get isNarrowLayout => MediaQuery.sizeOf(this).width <= MXBreakpoints.narrow;

  /// 页面左右留白（设计稿 `pad-x`：桌面 20 / 移动 14）
  double get mxPadX => isMobileLayout ? 14 : 20;

  /// 日志列表左右留白：手机上压到最小（只留一点点不贴边），
  /// 屏幕本来就窄，边距吃掉的都是日志正文的显示宽度
  double get mxListPadX => isMobileLayout ? 2 : 20;

  /// 底部安全区（刘海屏 home indicator）：列表底部留白、悬浮按钮、弹窗底栏需避让。
  /// 嵌入模式下分析器贴着屏幕底部，这个值不为 0。
  double get mxSafeBottom => MediaQuery.viewPaddingOf(this).bottom;

  /// header 右上角操作按钮尺寸（设计稿 `topbar button`：30 → 38）
  double get mxTopButtonSize => isMobileLayout ? 38 : 30;

  /// 日志卡片头部操作按钮尺寸（设计稿 `row-head button`：28 → 36）
  double get mxRowButtonSize => isMobileLayout ? 36 : 28;

  /// 回顶/回底悬浮按钮尺寸（设计稿 `fab button`：36 → 44）
  double get mxFabSize => isMobileLayout ? 44 : 36;

  /// 输入框字号：移动端统一放大到 16（设计稿 `page input{font-size:16px}`），
  /// 手机上小字号输入既难认也难点。
  double mxInputFontSize(double desktopSize) => isMobileLayout ? 16 : desktopSize;
}
