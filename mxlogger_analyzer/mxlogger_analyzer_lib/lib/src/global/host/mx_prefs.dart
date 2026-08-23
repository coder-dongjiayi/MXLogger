/// 分析器需要的最小本地存储能力（主题 / 语言 / 解密参数 / 已进入标记）。
///
/// 抽成接口而不是直接用 shared_preferences：嵌入宿主 app 时 KEY/IV 由
/// `MXAnalyzer.showDebug` 传入、不需要落盘，默认用 [MXMemoryPrefs] 即可，
/// 于是移动端集成分析器不必为它引入一个 KV 存储插件（宿主业务层往往
/// 已经有自己的存储方案，多一份依赖只会打架）。
/// 桌面壳无所谓多依赖，自行用 shared_preferences 实现本接口注入即可。
///
/// 读取同步、写入 fire-and-forget（实现内部落盘可以是异步的），
/// 与 SharedPreferences 的用法一致。
abstract interface class MXPrefs {
  String? getString(String key);

  bool? getBool(String key);

  void setString(String key, String value);

  void setBool(String key, bool value);
}

/// 默认实现：只存在内存里。
///
/// 不落盘意味着「重启后设置回到默认值」，这对嵌入模式是合理的：
/// 日志目录与解密参数每次都由宿主 `showDebug` 传入，用户在分析器里
/// 临时加的组、切的主题/语言只在本次进程内有效。
/// 需要持久化的宿主可以自己实现 [MXPrefs] 并经 `MXAnalyzer.initialize` 注入。
class MXMemoryPrefs implements MXPrefs {
  MXMemoryPrefs([Map<String, Object> initial = const <String, Object>{}])
      : _values = Map<String, Object>.of(initial);

  final Map<String, Object> _values;

  /// 类型不符时当没存过（而非抛异常）：存储内容变脏不该让分析器打不开
  @override
  String? getString(String key) {
    final Object? value = _values[key];
    return value is String ? value : null;
  }

  @override
  bool? getBool(String key) {
    final Object? value = _values[key];
    return value is bool ? value : null;
  }

  @override
  void setString(String key, String value) => _values[key] = value;

  @override
  void setBool(String key, bool value) => _values[key] = value;
}
