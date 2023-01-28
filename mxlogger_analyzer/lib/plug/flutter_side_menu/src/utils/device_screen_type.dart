enum DeviceScreenType {
  desktop(breakpoint: 950),
  tablet(breakpoint: 600),
  mobile(breakpoint: 320);

  const DeviceScreenType({
    required this.breakpoint,
  });

  final int breakpoint;

  static bool isDesktop({
    required double width,
  }) =>
      width >= DeviceScreenType.desktop.breakpoint;

  static bool isTablet({
    required double width,
  }) =>
      width >= DeviceScreenType.tablet.breakpoint &&
      width < DeviceScreenType.desktop.breakpoint;

  static bool isMobile({
    required double width,
  }) =>
      width >= DeviceScreenType.mobile.breakpoint &&
      width < DeviceScreenType.tablet.breakpoint;
}
