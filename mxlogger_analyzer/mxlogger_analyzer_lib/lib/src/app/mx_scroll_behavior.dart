import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Keeps macOS trackpad velocity samples valid when timestamps arrive out of order.
class MXScrollBehavior extends MaterialScrollBehavior {
  const MXScrollBehavior();

  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    final GestureVelocityTrackerBuilder platformBuilder = super
        .velocityTrackerBuilder(context);
    if (getPlatform(context) != TargetPlatform.macOS) return platformBuilder;

    return (PointerEvent event) => event.kind == PointerDeviceKind.trackpad
        ? _TimestampSafeMacOSVelocityTracker(event.kind)
        : platformBuilder(event);
  }
}

class _TimestampSafeMacOSVelocityTracker extends VelocityTracker {
  _TimestampSafeMacOSVelocityTracker(super.kind)
    : _tracker = MacOSScrollViewFlingVelocityTracker(kind),
      super.withKind();

  MacOSScrollViewFlingVelocityTracker _tracker;
  Duration? _lastTime;

  @override
  void addPosition(Duration time, Offset position) {
    final Duration? lastTime = _lastTime;
    if (lastTime != null && time < lastTime) {
      // Start a fresh history in the new time range; mixing the ranges would
      // assert in Flutter and distort the fling estimate in release.
      _tracker = MacOSScrollViewFlingVelocityTracker(kind);
    }
    _tracker.addPosition(time, position);
    _lastTime = time;
  }

  @override
  VelocityEstimate getVelocityEstimate() => _tracker.getVelocityEstimate();
}
