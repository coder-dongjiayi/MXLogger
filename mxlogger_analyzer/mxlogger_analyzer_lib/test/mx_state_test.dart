import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_scope.dart';
import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';

import 'support/test_store.dart';

/// 自研 stream 状态管理的基础语义：赋值通知、相等不通知、
/// 异步态懒加载/刷新保留旧值，以及组件侧 watch / select / listen 的重建规则。
void main() {
  group("MXState", () {
    test("赋值广播新值，相等值不通知", () {
      final MXState<int> state = MXState<int>(0);
      final List<int> events = [];
      state.stream.listen(events.add);

      state.value = 1;
      state.value = 1;
      state.update((int value) => value + 1);

      expect(state.value, 2);
      expect(events, [1, 2]);
      state.dispose();
    });

    test("监听回调里回写同一状态：不重入报错，本轮结束后补发最新值", () {
      final MXState<int> state = MXState<int>(0);
      final List<int> events = [];
      state.stream.listen((int value) {
        events.add(value);
        // 「消费完即复位」写法：回调内回写同一状态
        if (value == 1) state.value = 0;
      });

      state.value = 1;

      expect(state.value, 0);
      expect(events, [1, 0]);
      state.dispose();
    });

    test("dispose 后不再接受写入", () {
      final MXState<int> state = MXState<int>(0)..dispose();
      state.value = 9;
      expect(state.value, 0);
      expect(state.isDisposed, isTrue);
    });
  });

  group("MXAsyncState", () {
    test("首次读值才触发取数，完成后进入 data 态", () async {
      int calls = 0;
      final MXAsyncState<int> state = MXAsyncState<int>(() async {
        calls++;
        return 42;
      });

      // 未被观察：不取数
      expect(calls, 0);
      expect(state.isStarted, isFalse);

      expect(await state.future, 42);
      expect(calls, 1);
      expect(state.value.hasValue, isTrue);
      expect(state.value.isLoading, isFalse);
      state.dispose();
    });

    test("refresh 期间保留旧值；未被观察过的 refresh 不取数", () async {
      int calls = 0;
      final MXAsyncState<int> state = MXAsyncState<int>(() async => ++calls);

      // 未观察 → refresh 空转
      await state.refresh();
      expect(calls, 0);

      expect(await state.future, 1);
      final Future<void> refreshing = state.refresh();
      // 刷新中仍可读旧值，界面不闪空
      expect(state.value.isLoading, isTrue);
      expect(state.value.hasValue, isTrue);
      expect(state.value.value, 1);

      await refreshing;
      expect(state.value.value, 2);
      state.dispose();
    });

    test("取数抛出归入 failure 态", () async {
      final MXAsyncState<int> state =
          MXAsyncState<int>(() => throw StateError("boom"));
      state.value; // 触发加载
      await Future<void>.delayed(Duration.zero);
      expect(state.value.hasError, isTrue);
      expect(state.value.hasValue, isFalse);
      state.dispose();
    });
  });

  group("MXRef", () {
    testWidgets("watch 变化重建；select 派生值不变则不重建", (WidgetTester tester) async {
      final MXStore store = await createTestStore();
      int cardBuilds = 0;

      await tester.pumpWidget(MXScope(
        store: store,
        child: MXConsumer(builder: (BuildContext context, MXRef ref) {
          cardBuilds++;
          final bool collapsed =
              ref.select(ref.store.foldToggled, (Set<int> set) => set.contains(1));
          return Text("$collapsed", textDirection: TextDirection.ltr);
        }),
      ));
      expect(cardBuilds, 1);
      expect(find.text("false"), findsOneWidget);

      // 与本组件无关的 id 变化：派生值不变，不重建
      store.foldToggled.value = {2};
      await tester.pump();
      expect(cardBuilds, 1);

      // 关心的 id 变化：重建
      store.foldToggled.value = {1, 2};
      await tester.pump();
      expect(cardBuilds, 2);
      expect(find.text("true"), findsOneWidget);
    });

    testWidgets("build 中不再 watch 的状态自动退订", (WidgetTester tester) async {
      final MXStore store = await createTestStore();
      int builds = 0;

      await tester.pumpWidget(MXScope(
        store: store,
        child: MXConsumer(builder: (BuildContext context, MXRef ref) {
          builds++;
          // timeOpen 为 true 时才关心 allCollapsed
          final bool timeOpen = ref.watch(ref.store.timeOpen);
          final bool allCollapsed =
              timeOpen ? ref.watch(ref.store.allCollapsed) : false;
          return Text("$timeOpen$allCollapsed", textDirection: TextDirection.ltr);
        }),
      ));
      expect(builds, 1);

      // 未被 watch：不重建
      store.allCollapsed.value = true;
      await tester.pump();
      expect(builds, 1);

      store.timeOpen.value = true;
      await tester.pump();
      expect(builds, 2);

      // 现在 watch 了：重建
      store.allCollapsed.value = false;
      await tester.pump();
      expect(builds, 3);
    });
  });
}
