import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// flutter drive 宿主侧 driver: 把集成测试里 takeScreenshot 的截图落盘到 screenshots/
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes);
      return true;
    },
  );
}
