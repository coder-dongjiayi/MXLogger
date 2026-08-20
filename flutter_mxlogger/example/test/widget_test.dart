import 'package:flutter_test/flutter_test.dart';

import 'package:example/demo_l10n.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('落地页正常渲染', (tester) async {
    await tester.pumpWidget(const MXDemoApp());
    expect(find.text('MXLogger'), findsOneWidget);
    // 文案跟随 demo 当前语言(默认英文)，用语言包取，避免写死某一种语言
    expect(find.text(tr('landing.enter')), findsOneWidget);
    expect(find.text(tr('landing.subtitle')), findsOneWidget);
    expect(find.text(DemoL10n.switchButtonTitle), findsOneWidget);
  });

  testWidgets('切换语言后落地页文案随之变化', (tester) async {
    await tester.pumpWidget(const MXDemoApp());
    final before = tr('landing.enter');
    expect(find.text(before), findsOneWidget);

    // 直接改语言(不走按钮，避免测试环境里 path_provider 持久化不可用)
    DemoL10n.language.value = DemoL10n.zh;
    await tester.pump();

    final after = tr('landing.enter');
    expect(after, isNot(before));
    expect(find.text(after), findsOneWidget);
    expect(find.text(before), findsNothing);

    DemoL10n.language.value = DemoL10n.en; // 还原，避免影响其他用例
  });
}
