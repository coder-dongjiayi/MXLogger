import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:mxlogger_analyzer_lib/src/global/state/mx_state.dart';
import 'package:mxlogger_analyzer_lib/src/global/store/mx_store.dart';

/// 向组件树注入 [MXStore]：分析器所有状态的入口。
/// 独立 app 在 runApp 处包一层，嵌入模式在弹窗根节点包一层。
class MXScope extends InheritedWidget {
  const MXScope({super.key, required this.store, required super.child});

  final MXStore store;

  static MXStore of(BuildContext context) {
    // store 全程不变，无需建立依赖（也因此可在 initState 中调用）
    final MXScope? scope = context.getInheritedWidgetOfExactType<MXScope>();
    assert(scope != null, "组件树上缺少 MXScope");
    return scope!.store;
  }

  @override
  bool updateShouldNotify(MXScope oldWidget) => oldWidget.store != store;
}

/// 组件侧状态入口：
/// - [watch]/[select]：build 中调用，值变化时重建组件；
/// - [read]：只取值不订阅（事件回调里用）；
/// - [listen]：注册副作用，在 initState 里调用一次。
///
/// build 结束后本次未再 watch 的状态自动退订，组件销毁时全部退订。
class MXRef {
  MXRef(this.store, this._onChange);

  final MXStore store;
  final VoidCallback _onChange;

  final Map<Object, _MXWatchEntry> _watches = {};
  final Set<Object> _usedKeys = {};
  final List<StreamSubscription<Object?>> _listeners = [];

  /// select 在同一次 build 内按调用顺序编号，作为订阅身份
  int _selectSequence = 0;

  /// 由框架侧（consumer 组件）在 build 前后调用
  void beginBuild() {
    _usedKeys.clear();
    _selectSequence = 0;
  }

  void endBuild() {
    _watches.removeWhere((Object key, _MXWatchEntry entry) {
      if (_usedKeys.contains(key)) return false;
      entry.subscription.cancel();
      return true;
    });
  }

  /// 订阅整个状态：值变化即重建
  T watch<T>(MXState<T> state) {
    _bind<T, T>(state, state, null);
    return state.value;
  }

  /// 只关心派生值：派生结果不变则不重建（如「本条日志是否折叠」）
  R select<T, R>(MXState<T> state, R Function(T value) selector) {
    _bind<T, R>(_SelectKey(state, _selectSequence++), state, selector);
    return selector(state.value);
  }

  /// 取值但不订阅
  T read<T>(MXState<T> state) => state.value;

  /// 状态变化副作用（不触发重建）。在 initState 调用一次，随组件销毁退订。
  void listen<T>(MXState<T> state, void Function(T previous, T next) onChange) {
    T previous = state.value;
    _listeners.add(state.stream.listen((T next) {
      final T old = previous;
      previous = next;
      onChange(old, next);
    }));
  }

  void dispose() {
    for (final _MXWatchEntry entry in _watches.values) {
      entry.subscription.cancel();
    }
    _watches.clear();
    for (final StreamSubscription<Object?> subscription in _listeners) {
      subscription.cancel();
    }
    _listeners.clear();
  }

  void _bind<T, R>(Object key, MXState<T> state, R Function(T value)? selector) {
    _usedKeys.add(key);
    R snapshotOf(T value) => selector == null ? value as R : selector(value);

    final _MXWatchEntry? existing = _watches[key];
    if (existing != null) {
      // 同一状态重复 watch / 重建后再次 watch：只更新快照，复用订阅
      existing.snapshot = snapshotOf(state.value);
      return;
    }
    final _MXWatchEntry entry = _MXWatchEntry(snapshotOf(state.value));
    entry.subscription = state.stream.listen((T value) {
      final Object? next = snapshotOf(value);
      if (next == entry.snapshot) return;
      entry.snapshot = next;
      _onChange();
    });
    _watches[key] = entry;
  }
}

class _MXWatchEntry {
  _MXWatchEntry(this.snapshot);

  late StreamSubscription<Object?> subscription;
  Object? snapshot;
}

/// select 的订阅身份：同一状态在同一组件内的第 n 次 select
class _SelectKey {
  const _SelectKey(this.state, this.index);

  final MXState<Object?> state;
  final int index;

  @override
  bool operator ==(Object other) =>
      other is _SelectKey && other.state == state && other.index == index;

  @override
  int get hashCode => Object.hash(state, index);
}

/// 状态在 build 阶段内变化时推迟重建，避免 setState during build。
void _rebuildSafely(State<StatefulWidget> state, VoidCallback rebuild) {
  if (!state.mounted) return;
  final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks ||
      phase == SchedulerPhase.midFrameMicrotasks) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.mounted) rebuild();
    });
    return;
  }
  rebuild();
}

/// 持有 [MXRef] 的组件状态，供 element 在 build 前后追踪订阅
abstract class _MXRefHolder {
  MXRef get ref;
}

/// 无自身状态的状态消费组件：在 build 里用 ref.watch 订阅。
abstract class MXConsumerWidget extends StatefulWidget {
  const MXConsumerWidget({super.key});

  Widget build(BuildContext context, MXRef ref);

  @override
  State<MXConsumerWidget> createState() => _MXConsumerWidgetState();
}

class _MXConsumerWidgetState extends State<MXConsumerWidget> {
  MXRef? _ref;

  MXRef get _reference => _ref ??= MXRef(MXScope.of(context), _handleChange);

  void _handleChange() => _rebuildSafely(this, () => setState(() {}));

  @override
  void dispose() {
    _ref?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MXRef ref = _reference;
    ref.beginBuild();
    final Widget child = widget.build(context, ref);
    ref.endBuild();
    return child;
  }
}

/// 内联消费：局部订阅状态而不新建组件类。
class MXConsumer extends MXConsumerWidget {
  const MXConsumer({super.key, required this.builder});

  final Widget Function(BuildContext context, MXRef ref) builder;

  @override
  Widget build(BuildContext context, MXRef ref) => builder(context, ref);
}

/// 有自身状态（controller / 动画等）的状态消费组件，配合 [MXConsumerState]。
abstract class MXConsumerStatefulWidget extends StatefulWidget {
  const MXConsumerStatefulWidget({super.key});

  @override
  MXConsumerState<MXConsumerStatefulWidget> createState();

  @override
  StatefulElement createElement() => _MXConsumerElement(this);
}

/// 包裹 State.build，使子类照常写 build 也能追踪 watch 订阅
class _MXConsumerElement extends StatefulElement {
  _MXConsumerElement(MXConsumerStatefulWidget super.widget);

  @override
  Widget build() {
    final MXRef ref = (state as _MXRefHolder).ref;
    ref.beginBuild();
    final Widget child = super.build();
    ref.endBuild();
    return child;
  }
}

abstract class MXConsumerState<W extends MXConsumerStatefulWidget> extends State<W>
    implements _MXRefHolder {
  MXRef? _ref;

  @override
  MXRef get ref => _ref ??= MXRef(MXScope.of(context), _handleChange);

  /// 便捷访问：等价于 ref.store
  MXStore get store => ref.store;

  void _handleChange() => _rebuildSafely(this, () => setState(() {}));

  @override
  void dispose() {
    _ref?.dispose();
    super.dispose();
  }
}
