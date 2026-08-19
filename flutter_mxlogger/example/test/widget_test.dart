import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('落地页正常渲染', (tester) async {
    await tester.pumpWidget(const MXDemoApp());
    expect(find.text('MXLogger'), findsOneWidget);
    expect(find.text('进入演示控制台'), findsOneWidget);
    expect(find.text('基于 mmap 的高性能跨平台日志库'), findsOneWidget);
  });
}
