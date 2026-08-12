import 'dart:async';

/// 最小状态单元：同步持有当前值，值变化时通过广播 stream 通知订阅者。
///
/// ```dart
/// final MXState<int> counter = MXState<int>(0);
/// counter.stream.listen(print);   // 只收后续变化
/// counter.value = 1;             // 通知
/// counter.update((int v) => v + 1);
/// ```
/// 业务侧一般继承它，把「怎么改」的逻辑收进子类（见 ThemeModeStore 等）。
class MXState<T> {
  MXState(this._value);

  T _value;
  bool _disposed = false;

  /// 正在派发通知（sync 控制器不允许派发期间再次 add）
  bool _firing = false;

  /// 派发期间又被写入：本轮结束后补发一次最新值
  bool _pendingNotify = false;

  /// sync 广播：赋值即同步通知，读值与通知顺序一致，测试无需额外等待
  final StreamController<T> _controller = StreamController<T>.broadcast(sync: true);

  T get value => _value;

  /// 值变化流（不含当前值，订阅后只收到后续变化）
  Stream<T> get stream => _controller.stream;

  bool get isDisposed => _disposed;

  /// 相等值不通知（== 语义），避免无意义重建
  set value(T next) {
    if (_disposed || _value == next) return;
    _value = next;
    _notify();
  }

  /// 基于旧值计算新值
  void update(T Function(T value) updater) => value = updater(_value);

  /// 通知订阅者。监听回调里回写同一状态（如「消费完结果即复位」）是常见写法，
  /// 此时不能重入 add，改为本轮派发结束后补发一次最新值。
  void _notify() {
    if (_firing) {
      _pendingNotify = true;
      return;
    }
    _firing = true;
    try {
      _controller.add(_value);
      while (_pendingNotify && !_disposed) {
        _pendingNotify = false;
        _controller.add(_value);
      }
    } finally {
      _pendingNotify = false;
      _firing = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.close();
  }
}

/// 异步取数快照：加载中 / 有值 / 失败三态并存（刷新时保留旧值）。
class MXAsync<T> {
  const MXAsync._({
    this.value,
    this.error,
    this.isLoading = false,
    this.hasValue = false,
  });

  const MXAsync.loading() : this._(isLoading: true);

  const MXAsync.data(T value) : this._(value: value, hasValue: true);

  const MXAsync.failure(Object error) : this._(error: error);

  final T? value;
  final Object? error;

  /// 取数进行中（刷新时 hasValue 可同时为 true，旧值仍可用）
  final bool isLoading;
  final bool hasValue;

  T? get valueOrNull => value;

  bool get hasError => error != null;

  /// 刷新：进入加载中但保留旧值，避免界面闪空
  MXAsync<T> toLoading() => MXAsync<T>._(
        value: value,
        error: error,
        isLoading: true,
        hasValue: hasValue,
      );

  @override
  bool operator ==(Object other) {
    return other is MXAsync<T> &&
        other.value == value &&
        other.error == error &&
        other.isLoading == isLoading &&
        other.hasValue == hasValue;
  }

  @override
  int get hashCode => Object.hash(value, error, isLoading, hasValue);
}

/// 异步取数状态：首次被观察（读值 / 订阅 / 取 future）时自动加载，
/// [refresh] 重新取数。未被观察过的状态 refresh 不做事，等首次观察再加载
/// ——对齐原先 autoDispose + invalidate 的效果，避免无人关心的空跑查询。
class MXAsyncState<T> extends MXState<MXAsync<T>> {
  MXAsyncState([Future<T> Function()? load])
      : _loader = load,
        super(MXAsync<T>.loading());

  final Future<T> Function()? _loader;

  int _generation = 0;
  bool _started = false;
  Future<T>? _inFlight;

  /// 取数实现：构造时未传 loader 的子类必须覆写
  Future<T> load() {
    final Future<T> Function()? loader = _loader;
    if (loader == null) {
      throw UnimplementedError("MXAsyncState 子类需覆写 load()");
    }
    return loader();
  }

  /// 是否已被观察过（据此决定 refresh 是否真的取数）
  bool get isStarted => _started;

  /// 当前取数代号：异步回调据此丢弃过期结果
  int get generation => _generation;

  @override
  MXAsync<T> get value {
    _ensureStarted();
    return super.value;
  }

  @override
  Stream<MXAsync<T>> get stream {
    _ensureStarted();
    return super.stream;
  }

  /// 最近一次取数结果：已有值直接返回，否则等待进行中的取数
  Future<T> get future {
    _ensureStarted();
    final Future<T>? inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final MXAsync<T> current = super.value;
    if (current.hasValue) return Future<T>.value(current.value as T);
    final Object? error = current.error;
    if (error != null) return Future<T>.error(error);
    return _run().then((_) => super.value.value as T);
  }

  /// 重新取数（未被观察过则不做事）
  Future<void> refresh() {
    if (!_started || isDisposed) return Future<void>.value();
    return _run();
  }

  /// 直接写入数据（如分页追加），视为当前最新结果
  void setData(T data) {
    _inFlight = null;
    super.value = MXAsync<T>.data(data);
  }

  void _ensureStarted() {
    if (_started || isDisposed) return;
    _started = true;
    _run();
  }

  Future<void> _run() {
    final int generation = ++_generation;
    super.value = super.value.toLoading();
    // Future.sync：load() 同步抛出也归一为失败态，不冒泡到读值方
    final Future<T> pending = Future<T>.sync(load);
    _inFlight = pending;
    return pending.then(
      (T data) {
        if (isDisposed || generation != _generation) return;
        _inFlight = null;
        super.value = MXAsync<T>.data(data);
      },
      onError: (Object error) {
        if (isDisposed || generation != _generation) return;
        _inFlight = null;
        super.value = MXAsync<T>.failure(error);
      },
    );
  }
}
