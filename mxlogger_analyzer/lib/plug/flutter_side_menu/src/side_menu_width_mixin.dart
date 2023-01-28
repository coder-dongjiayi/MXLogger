import 'utils/device_screen_type.dart';
import 'side_menu_mode.dart';
import 'side_menu_priority.dart';
import 'utils/constants.dart';

mixin SideMenuWidthMixin {
  late SideMenuMode mode;
  late SideMenuPriority priority;
  late bool hasResizer;
  late double currentWidth;
  late double deviceWidth;
  late double minWidth;
  late double maxWidth;

  double calculateWidthSize({
    required SideMenuMode mode,
    required bool hasResizer,
    required double minWidth,
    required double maxWidth,
    required double currentWidth,
    required double deviceWidth,
    required SideMenuPriority priority,
  }) {
    this.mode = mode;
    this.priority = priority;
    this.hasResizer = hasResizer;
    this.minWidth = minWidth;
    this.maxWidth = maxWidth;
    this.currentWidth = currentWidth;
    this.deviceWidth = deviceWidth;

    switch (mode) {
      case SideMenuMode.open:
        return _open();
      case SideMenuMode.compact:
        return _compact();
      case SideMenuMode.auto:
      default:
        return _auto();
    }
  }

  double _auto() {
    if (_isPossibleWidthChange()) {
      if (DeviceScreenType.isDesktop(width: deviceWidth)) {
        return maxWidth;
      } else {
        return minWidth;
      }
    }
    return currentWidth;
  }

  double _open() {
    if (_isPossibleWidthChange()) {
      return maxWidth;
    }
    return currentWidth;
  }

  double _compact() {
    if (_isPossibleWidthChange()) {
      return minWidth;
    }
    return currentWidth;
  }

  bool _isPossibleWidthChange() {
    if (!hasResizer ||
        priority == SideMenuPriority.mode ||
        currentWidth == Constants.zeroWidth) {
      return true;
    } else {
      return !_isCurrentWidthCustom();
    }
  }

  bool _isCurrentWidthCustom() {
    if (currentWidth == maxWidth || currentWidth == minWidth) {
      return false;
    } else {
      return true;
    }
  }
}
