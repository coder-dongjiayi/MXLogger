import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer/src/util/date_util.dart';

extension DateTimeEx on DateTime {
  String get formatDateLogTime {
    try {
      return DateUtil.formatDateMs(millisecondsSinceEpoch,
          isUtc: false, format: "yyyy-MM-dd HH:mm:ss");
    } catch (e) {
      return "--";
    }
  }

  String get formatDateLogTimeYMD {
    try {
      return DateUtil.formatDateMs(millisecondsSinceEpoch,
          isUtc: false, format: "yyyy-MM-dd");
    } catch (e) {
      return "--";
    }
  }

  String get formatDateLogTimeHMS {
    try {
      return DateUtil.formatDateMs(millisecondsSinceEpoch,
          isUtc: false, format: "HH:mm:ss");
    } catch (e) {
      return "--";
    }
  }
}

extension TimeOfDayExt on TimeOfDay {
  String get formatDateLogTimeHMS {
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateUtil.formatDateMs(dt.millisecondsSinceEpoch,
          isUtc: false, format: "HH:mm:ss");
    } catch (e) {
      return "--";
    }
  }
}
