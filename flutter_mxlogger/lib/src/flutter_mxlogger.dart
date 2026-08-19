import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

List<String> _levelIcons = ["🟩", "🟦", "🟨", "🟥", "❌"];
List<String> _levelNames = ["DEBUG", "INFO", "WARN", "ERROR", "FATAL"];

/// 日志文件存储策略
/// Log file storage policy
enum MXStoragePolicyType {
  /// 按天存储 对应文件名: 2023-01-11_filename.mx
  /// One file per day, e.g. 2023-01-11_filename.mx
  yyyy_MM_dd,

  /// 按小时存储 对应文件名: 2023-01-11-15_filename.mx
  /// One file per hour, e.g. 2023-01-11-15_filename.mx
  yyyy_MM_dd_HH,

  /// 按周存储 对应文件名: 2023-01-02w_filename.mx（02w是指一年中的第2周）
  /// One file per week, e.g. 2023-01-02w_filename.mx (02w means the 2nd week of the year)
  yyyy_ww,

  /// 按月存储 对应文件名: 2023-01_filename.mx
  /// One file per month, e.g. 2023-01_filename.mx
  yyyy_MM
}

/// 日志文件信息实体
/// Metadata of a stored log file
class MXFileEntity {
  /// 文件名
  /// File name
  late String? name;

  /// 文件大小(byte)
  /// File size in bytes
  late int size;

  /// 文件创建时间戳(秒)
  /// File creation timestamp in seconds
  late int createTimeStamp;

  /// 文件最后修改时间戳(秒)
  /// Last-modified timestamp in seconds
  late int lastTimeStamp;

  /// 文件创建时间
  /// File creation time
  DateTime get createTime =>
      DateTime.fromMillisecondsSinceEpoch(createTimeStamp * 1000);

  /// 文件最后修改时间
  /// Last-modified time
  DateTime get lastTime =>
      DateTime.fromMillisecondsSinceEpoch(lastTimeStamp * 1000);

  MXFileEntity(
      {this.name,
      this.size = 0,
      this.createTimeStamp = 0,
      this.lastTimeStamp = 0});
  @override
  String toString() {
    return "name:$name size:$size createTime:$createTime lastTime:$lastTime";
  }
}

class MXLogger with WidgetsBindingObserver {
  Pointer<Void> _handle = nullptr;

  static const MethodChannel _channel = MethodChannel('flutter_mxlogger');
  static bool _consoleEnable = false;
  IOSink? _ioSink;

  /// 日志写入功能是否开启
  /// Whether logging is enabled
  bool get enable => _enable;

  /// 控制台打印是否开启(flutter层输出)
  /// Whether console printing is enabled (output from the Flutter layer)
  bool get consoleEnable => _consoleEnable;

  /// 运行时开关控制台打印。
  /// native侧输出在初始化时已被禁用，日志统一由flutter层debugPrint输出，
  /// 因此这里只需要更新flutter层的开关。
  /// Toggle console printing at runtime.
  /// Native-side console output is disabled at initialization — all console output
  /// goes through the Flutter layer's debugPrint, so only the Flutter-side flag is updated here.
  void setConsoleEnable(bool enable) {
    _consoleEnable = enable;
  }

  /// 获取写入日志的错误信息，当[log]方法返回值 != 0 的时候调用
  /// Get the write-error description; check it when [log] returns a non-zero value
  String? get errorDesc => _errorDesc();

  /// 获取日志文件夹的磁盘路径(directory+nameSpace)
  /// Get the disk path of the log directory (directory + nameSpace)
  String get diskcachePath => getDiskcachePath();

  /// 获取错误文件路径
  /// Get the path of the local error-record file
  String get diskcacheErrorPath => diskcachePath + "/error.txt";

  /// 获取日志底层的唯一标识，可以通过这个key操作日志对象。
  /// 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)，
  /// 但是你希望所有子模块(子组件)使用在主工程初始化的log，
  /// 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey进行日志写入
  /// Get the unique key of the underlying logger, usable to operate on it.
  /// Use case: in a large modularized app, sub-modules can share the logger initialized
  /// in the main project by passing this key around (instead of the logger object) and
  /// writing logs via [logLoggerKey] — keeping modules decoupled
  String? get loggerKey => getLoggerKey();

  /// 获取存储的日志大小(byte)
  /// Get the total size of stored logs in bytes
  int get logSize => getLogSize();

  /// 获取日志文件列表
  /// Get the list of stored log files
  List<MXFileEntity> get logFiles => getLogFiles();

  /// 初始化时传入的加密key
  /// The encryption key passed at initialization
  String? get cryptKey => _cryptKey;

  /// 初始化时传入的加密向量
  /// The initialization vector passed at initialization
  String? get iv => _iv;

  /// 监听App生命周期：进入后台时按需清理过期日志文件
  /// Observe the app lifecycle: remove expired log files when entering background (if enabled)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused &&
        _shouldRemoveExpiredDataWhenEnterBackground == true) {
      removeExpireData();
    }
  }

  /// 使用自定义路径初始化MXLogger
  /// Initialize MXLogger with a custom directory
  ///
  /// nameSpace: 日志文件的命名空间，建议使用域名反转保证唯一性
  ///            namespace of the log files; a reverse-domain name is recommended for uniqueness
  /// directory: 自定义日志文件路径 / custom log directory
  /// consoleEnable: 是否开启控制台打印 / whether to enable console printing
  /// storagePolicy: 日志文件存储策略 / log file storage policy
  /// fileName: 自定义文件名 / custom file name
  /// fileHeader: 日志文件头信息，业务可以在初始化mxlogger的时候写入一些业务相关的信息，
  ///             比如app版本、所属平台等等，文件创建的时候这条数据会被写入
  ///             file header; the business layer can write context info (app version,
  ///             platform, etc.), written once when the file is created
  /// cryptKey: 如果日志信息需要加密需要填入这个值，16字节：超过16字节自动截断 不足16字节补0
  ///           encryption key, required for encrypted logs; 16 bytes:
  ///           truncated if longer, zero-padded if shorter
  /// iv: 如果不填默认和cryptKey一致 / defaults to cryptKey when omitted
  MXLogger(
      {required String nameSpace,
      required String directory,
      bool consoleEnable = false,
      MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyy_MM_dd,
      String? fileName,
      String? fileHeader,
      String? cryptKey,
      String? iv}) {
    _cryptKey = cryptKey;
    _iv = iv;
    _consoleEnable = consoleEnable;
    WidgetsBinding.instance.addObserver(this);

    Pointer<Utf8> nsPtr = nameSpace.toNativeUtf8();
    Pointer<Utf8> drPtr = directory.toNativeUtf8();

    String policy =
        storagePolicy.toString().replaceAll("MXStoragePolicyType.", "");

    Pointer<Utf8> storagePolicyPtr = policy.toNativeUtf8();
    Pointer<Utf8> fileNamePtr =
        fileName == null ? nullptr : fileName.toNativeUtf8();
    Pointer<Utf8> fileHeaderPtr =
        fileHeader == null ? nullptr : fileHeader.toNativeUtf8();

    Pointer<Utf8> cryptKeyPtr =
        cryptKey == null ? nullptr : cryptKey.toNativeUtf8();

    Pointer<Utf8> ivPtr = iv == null ? nullptr : iv.toNativeUtf8();

    _handle = _initialize(nsPtr, drPtr, storagePolicyPtr, fileNamePtr,
        fileHeaderPtr, cryptKeyPtr, ivPtr);

    calloc.free(nsPtr);
    calloc.free(drPtr);
    if (storagePolicyPtr != nullptr) {
      calloc.free(storagePolicyPtr);
    }
    if (fileNamePtr != nullptr) {
      calloc.free(fileNamePtr);
    }
    if (fileHeaderPtr != nullptr) {
      calloc.free(fileHeaderPtr);
    }
    if (cryptKeyPtr != nullptr) {
      calloc.free(cryptKeyPtr);
    }
    if (ivPtr != nullptr) {
      calloc.free(ivPtr);
    }

    _nameSpace = nameSpace;
    _directory = directory;
    /// 注册到实例表：destroy时据此失效对应实例，防止use-after-free
    /// Register into the instance map so destroy can invalidate this instance
    final String? registerKey = getLoggerKey();
    if (registerKey != null) {
      _instanceMap[registerKey] = this;
    }
  }

  /// 初始化MXLogger（使用平台默认路径）
  /// Initialize MXLogger (with the platform default directory)
  ///
  /// nameSpace: 日志文件的命名空间，建议使用域名反转保证唯一性
  ///            namespace of the log files; a reverse-domain name is recommended for uniqueness
  /// directory: 自定义日志文件路径，不填时使用默认路径：
  ///            ios: /Library/com.mxlog.LoggerCache/nameSpace
  ///            android: /files/com.mxlog.LoggerCache/nameSpace
  ///            custom log directory; defaults to the paths above when omitted
  /// consoleEnable: 是否开启控制台打印 / whether to enable console printing
  /// storagePolicy: 日志文件存储策略 / log file storage policy
  /// fileName: 自定义文件名 默认值 mxlog / custom file name, defaults to "mxlog"
  /// fileHeader: 日志文件头信息，业务可以在初始化mxlogger的时候写入一些业务相关的信息，
  ///             比如app版本、所属平台等等，文件创建的时候这条数据会被写入
  ///             file header; the business layer can write context info (app version,
  ///             platform, etc.), written once when the file is created
  /// cryptKey: 如果日志信息需要加密需要填入这个值，16字节：超过16字节自动截断 不足16字节补0
  ///           encryption key, required for encrypted logs; 16 bytes:
  ///           truncated if longer, zero-padded if shorter
  /// iv: 如果不填默认和cryptKey一致 / defaults to cryptKey when omitted
  static Future<MXLogger> initialize(
      {required String nameSpace,
      String? directory,
      bool consoleEnable = false,
      MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyy_MM_dd,
      String? fileName,
      String? fileHeader,
      String? cryptKey,
      String? iv}) async {
    String ns = nameSpace;
    String dr = directory ?? "";

    Map<dynamic, dynamic> result = await _channel.invokeMethod(
        "initialize", {"nameSpace": nameSpace, "directory": directory});
    dr = result["directory"];

    MXLogger mxLogger = MXLogger(
        nameSpace: ns,
        directory: dr,
        consoleEnable: consoleEnable,
        storagePolicy: storagePolicy,
        fileName: fileName,
        fileHeader: fileHeader,
        cryptKey: cryptKey,
        iv: iv);

    return mxLogger;
  }

  /// 通过nameSpace+directory释放logger对象。
  /// 会先失效对应的Dart实例（移除生命周期监听、清空句柄），防止销毁后
  /// 进入后台的清理回调触碰已释放的native对象(use-after-free)；
  /// directory不传时用实例记录的实际目录补全——native侧收到null目录是静默无操作
  /// Release the logger identified by nameSpace + directory.
  /// Matching Dart instances are invalidated first (lifecycle observer removed,
  /// handle cleared) so the enter-background cleanup callback cannot touch the freed
  /// native object (use-after-free). When directory is omitted it is filled in from
  /// the instance's recorded directory — the native destroy is a silent no-op on a
  /// null directory
  static void destroy({required String nameSpace, String? directory}) {
    final List<String> keys = [];
    _instanceMap.forEach((key, logger) {
      if (logger._nameSpace == nameSpace &&
          (directory == null || logger._directory == directory)) {
        keys.add(key);
      }
    });
    for (final String key in keys) {
      final MXLogger? logger = _instanceMap.remove(key);
      if (logger == null) continue;
      final String? dr = directory ?? logger._directory;
      logger._invalidate();
      _destroyNative(nameSpace, dr);
    }
    /// 没有匹配的Dart实例时保持原有透传行为
    /// Fall through to the plain native call when no Dart instance matches
    if (keys.isEmpty) {
      _destroyNative(nameSpace, directory);
    }
  }

  static void _destroyNative(String nameSpace, String? directory) {
    Pointer<Utf8> nsPtr = nameSpace.toNativeUtf8();
    Pointer<Utf8> drPtr =
        directory == null ? nullptr : directory.toNativeUtf8();
    _destroy(nsPtr, drPtr);
    calloc.free(nsPtr);
    calloc.free(drPtr);
  }

  /// 通过loggerKey释放logger对象；同样会先失效对应的Dart实例
  /// Release the logger identified by loggerKey; the matching Dart instance
  /// is invalidated first
  static void destroyWithLoggerKey(String loggerKey) {
    final MXLogger? logger = _instanceMap.remove(loggerKey);
    logger?._invalidate();
    Pointer<Utf8> keyPtr = loggerKey.toNativeUtf8();
    _destroyWithLoggerKey(keyPtr);
    calloc.free(keyPtr);
  }

  /// 类方法：使用loggerKey写入日志（无需持有logger对象，适用于模块化场景）
  /// Class method: write a log entry via loggerKey (no logger instance needed,
  /// designed for modularized apps)
  ///
  /// loggerKey: logger的唯一标识 / unique key of the logger
  /// lvl: 日志等级 0:debug 1:info 2:warn 3:error 4:fatal
  ///      log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
  /// msg: 日志信息 / log message
  /// name: 日志名称 / logger name
  /// tag: 标记 / tag
  static void logLoggerKey(String? loggerKey, int lvl, String msg,
      {String? name, String? tag}) {
    if (_consoleEnable == true) {
      debugPrint(
          "-----------MXLogger-----------\nlevel:${_levelIcons[lvl]}${_levelNames[lvl]}\nname:$name\ntags:$tag\nmsg:$msg");
    }
    Pointer<Utf8> loggerKeyPtr =
        loggerKey != null ? loggerKey.toNativeUtf8() : nullptr;

    Pointer<Utf8> namePtr = name != null ? name.toNativeUtf8() : nullptr;
    Pointer<Utf8> tagPtr = tag != null ? tag.toNativeUtf8() : nullptr;
    Pointer<Utf8> msgPtr = msg.toNativeUtf8();

    _logLoggerKey(loggerKeyPtr, namePtr, lvl, msgPtr, tagPtr);

    calloc.free(loggerKeyPtr);
    calloc.free(namePtr);
    calloc.free(tagPtr);
    calloc.free(msgPtr);
  }

  /// 类方法：通过loggerKey写入debug等级日志
  /// Class method: write a debug-level log entry via loggerKey
  static void debugLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 0, msg, name: name, tag: tag);
  }

  /// 类方法：通过loggerKey写入info等级日志
  /// Class method: write an info-level log entry via loggerKey
  static void infoLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 1, msg, name: name, tag: tag);
  }

  /// 类方法：通过loggerKey写入warn等级日志
  /// Class method: write a warn-level log entry via loggerKey
  static void warnLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 2, msg, name: name, tag: tag);
  }

  /// 类方法：通过loggerKey写入error等级日志
  /// Class method: write an error-level log entry via loggerKey
  static void errorLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 3, msg, name: name, tag: tag);
  }

  /// 类方法：通过loggerKey写入fatal等级日志
  /// Class method: write a fatal-level log entry via loggerKey
  static void fatalLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 4, msg, name: name, tag: tag);
  }

  /// 程序进入后台的时候是否去清理过期文件 默认为true
  /// Whether to remove expired log files when the app enters background, defaults to true
  void shouldRemoveExpiredDataWhenEnterBackground(bool should) {
    _shouldRemoveExpiredDataWhenEnterBackground = should;
  }

  /// 设置写入日志文件等级，低于该等级的日志不会写入文件
  ///    0:debug 1:info 2:warn 3:error 4:fatal
  ///    lvl=0 >=0 的等级会被写入日志
  ///    lvl=1 >=1 的等级会被写入日志
  ///    lvl=2 >=2 的等级会被写入日志
  ///    .......
  /// Set the minimum level written to file; logs below this level are not written
  ///    0 debug, 1 info, 2 warn, 3 error, 4 fatal
  ///    e.g. lvl=1 means only logs with level >= 1 are written, and so on
  void setLevel(int lvl) {
    if (enable == false) return;
    _setLevel(_handle, lvl);
  }

  /// 设置是否开启日志写入功能，false时禁用日志
  /// Enable or disable logging; pass false to disable
  void setEnable(bool enable) {
    if (_handle == nullptr) return;
    _enable = enable;
    _setEnable(_handle, enable == true ? 1 : 0);
  }

  /// 设置日志文件存储最大时长(秒) 默认为0不限制，如 60 * 60 * 24 * 7 即一个星期；
  /// 以文件最后修改时间判断是否过期，过期文件在[removeExpireData]时删除
  /// Set the maximum age of log files in seconds; defaults to 0 (unlimited),
  /// e.g. 60 * 60 * 24 * 7 for one week. Expiry is judged by each file's last-modified
  /// time, and expired files are deleted when [removeExpireData] runs
  void setMaxDiskAge(int age) {
    if (enable == false) return;

    _setMaxDiskAge(_handle, age);
  }

  /// 设置日志文件存储最大字节数(byte) 默认为0不限制，如 1024 * 1024 * 10 即10M；
  /// 超限清理在[removeExpireData]时执行
  /// Set the maximum total size of log files in bytes; defaults to 0 (unlimited),
  /// e.g. 1024 * 1024 * 10 for 10 MB. The over-limit cleanup runs
  /// when [removeExpireData] is called
  void setMaxDiskSize(int size) {
    if (enable == false) return;
    _setMaxDiskSize(_handle, size);
  }

  /// 清理日志文件：先删除过期文件（最后修改时间超过maxDiskAge），若总大小仍超过maxDiskSize
  /// 则从最旧的文件开始继续删除；当前正在写入的文件不会被删除。
  /// App进入后台时默认会自动调用（见[shouldRemoveExpiredDataWhenEnterBackground]）
  /// Clean up log files: first delete expired files (last-modified time older than
  /// maxDiskAge), then, if the total size still exceeds maxDiskSize, keep deleting from
  /// the oldest file onward; the file currently being written is never deleted.
  /// Called automatically when the app enters background by default
  /// (see [shouldRemoveExpiredDataWhenEnterBackground])
  void removeExpireData() {
    if (enable == false) return;
    _removeExpireData(_handle);
  }

  /// 删除除当前正在写入文件之外的所有日志文件
  /// Remove all log files except the one currently being written
  void removeBeforeAllData() {
    if (enable == false) return;
    _removeBeforeAllData(_handle);
  }

  /// 删除所有日志文件
  /// Remove all log files
  void removeAll() {
    if (enable == false) return;
    _removeAll(_handle);
  }

  /// 获取存储的日志大小(byte)
  /// Get the total size of stored logs in bytes
  int getLogSize() {
    if (enable == false) return 0;
    return _getLogSize(_handle);
  }

  /// 获取日志文件夹的存储路径
  /// Get the disk path of the log directory
  String getDiskcachePath() {
    if (enable == false) return "";
    Pointer<Int8> result = _getDiskcachePath(_handle);
    if (result == nullptr) return "";
    String path = result.cast<Utf8>().toDartString();

    /// native侧strdup的内存必须由native侧释放
    /// Memory strdup-ed on the native side must be freed by the native side
    _freeString(result);
    return path;
  }

  /// 获取native侧最近一次写入失败的错误信息，无错误时返回null
  /// Get the most recent native write-error description, or null when there is none
  String? _errorDesc() {
    if (enable == false) return null;
    Pointer<Int8> result = _getErrorDesc(_handle);
    if (result == nullptr) return null;
    String error = result.cast<Utf8>().toDartString();
    _freeString(result);
    if (error.isEmpty == true) return null;
    return error;
  }

  /// 获取日志底层的唯一标识，可以通过这个key操作日志对象。
  /// 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)，
  /// 但是你希望所有子模块(子组件)使用在主工程初始化的log，
  /// 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey进行日志写入
  /// Get the unique key of the underlying logger, usable to operate on it.
  /// Use case: in a large modularized app, sub-modules can share the logger initialized
  /// in the main project by passing this key around and writing logs via [logLoggerKey]
  String? getLoggerKey() {
    if (_handle == nullptr) return null;
    Pointer<Int8> result = _getLoggerKey(_handle);
    if (result == nullptr) return null;
    String loggerKey = result.cast<Utf8>().toDartString();
    _freeString(result);
    return loggerKey;
  }

  /// 写入debug等级日志
  /// Write a debug-level log entry
  int debug(String msg, {String? name, String? tag}) {
    return log(0, msg, name: name, tag: tag);
  }

  /// 写入info等级日志
  /// Write an info-level log entry
  int info(String msg, {String? name, String? tag}) {
    return log(1, msg, name: name, tag: tag);
  }

  /// 写入warn等级日志
  /// Write a warn-level log entry
  int warn(String msg, {String? name, String? tag}) {
    return log(2, msg, name: name, tag: tag);
  }

  /// 写入error等级日志
  /// Write an error-level log entry
  int error(String msg, {String? name, String? tag}) {
    return log(3, msg, name: name, tag: tag);
  }

  /// 写入fatal等级日志
  /// Write a fatal-level log entry
  int fatal(String msg, {String? name, String? tag}) {
    return log(4, msg, name: name, tag: tag);
  }

  /// 写入日志
  /// 当返回值不等于0的时候，开发者可以调用[writeFail]方法写入错误信息到本地
  /// Write a log entry
  /// When the return value is non-zero, call [writeFail] to record the error locally
  ///
  /// lvl: 日志等级 0:debug 1:info 2:warn 3:error 4:fatal
  ///      log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
  /// msg: 日志信息 / log message
  /// name: 日志名称 / logger name
  /// tag: 标记 / tag
  /// 返回值: 0 成功 -1 扩容失败 -2 解除映射失败 -3 映射失败
  /// return: 0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
  int log(int lvl, String msg, {String? name, String? tag}) {
    if (enable == false) return 0;
    if (_consoleEnable == true) {
      debugPrint(
          "-----------MXLogger-----------\nlevel:${_levelIcons[lvl]}${_levelNames[lvl]}\nname:$name\ntags:$tag\nmsg:$msg");
    }
    Pointer<Utf8> namePtr = name != null ? name.toNativeUtf8() : nullptr;
    Pointer<Utf8> tagPtr = tag != null ? tag.toNativeUtf8() : nullptr;
    Pointer<Utf8> msgPtr = msg.toNativeUtf8();

    int result = _log(_handle, namePtr, lvl, msgPtr, tagPtr);

    calloc.free(namePtr);
    calloc.free(tagPtr);
    calloc.free(msgPtr);
    return result;
  }

  /// 当[log]返回值 != 0 时调用，将写入失败的错误信息以JSON格式追加到本地错误文件
  /// Call this when [log] returns a non-zero value; appends the failure info
  /// to the local error file as a JSON line
  ///
  /// code: [log]的返回值 / return value of [log]
  /// errorDesc: [errorDesc]的错误信息 / the error description from [errorDesc]
  /// other: 业务自定义信息 / extra business-defined info
  void writeFail(
      {required int code, required String errorDesc, String? other}) {
    /// 路径无效(初始化失败、已禁用或已销毁)时diskcachePath为空串，
    /// 继续写会拼出"/error.txt"指向根目录并抛异常
    /// diskcachePath is empty when the logger is uninitialized, disabled or
    /// destroyed; writing would target "/error.txt" at the filesystem root and throw
    if (diskcachePath.isEmpty) return;
    if (_ioSink == null) {
      File file = File(diskcacheErrorPath);
      _ioSink = file.openWrite(mode: FileMode.append);
    }
    Map<String, dynamic> map = {
      "code": code,
      "error": errorDesc,
      "other": other,
    };
    String jsonStr = json.encode(map);
    _ioSink?.write(jsonStr + "\n");
  }

  /// 删除本地错误文件
  /// Delete the local error file
  void deleteFailFile() {
    File file = File(diskcacheErrorPath);
    file.delete();
  }

  /// 关闭错误文件的写入流
  /// Close the write stream of the error file
  void closeFailFile() {
    _ioSink?.close();
    _ioSink = null;
  }

  /// 获取日志文件列表（文件名、大小、创建时间、最后修改时间）
  /// Get the list of stored log files (name, size, creation time, last-modified time)
  List<MXFileEntity> getLogFiles() {
    if (_handle == nullptr) return [];
    final arrayPtr = calloc<Pointer<Pointer<Pointer<Utf8>>>>();
    final sizeArrayPtr = calloc<Pointer<Pointer<Uint32>>>();
    final count = _getLogfiles(_handle, arrayPtr, sizeArrayPtr);
    List<MXFileEntity> _mxFileList = [];
    if (count > 0) {
      final arrayArray = arrayPtr[0];
      final sizeArrayArray = sizeArrayPtr[0];
      for (int i = 0; i < count; i++) {
        final charArray = arrayArray[i];

        final sizeArray = sizeArrayArray[i];

        final pointName = charArray[0];
        final pointSize = charArray[1];
        final pointLastTimestamp = charArray[2];
        final pointCreateTimestamp = charArray[3];

        final pointNameSize = sizeArray[0];
        final pointSizeSize = sizeArray[1];
        final pointLastTimestampSize = sizeArray[2];
        final pointCreateTimestampSize = sizeArray[3];

        String? name = _buffer2String(pointName.cast(), pointNameSize);
        String? size = _buffer2String(pointSize.cast(), pointSizeSize);
        String? lastTimestamp =
            _buffer2String(pointLastTimestamp.cast(), pointLastTimestampSize);

        String? createTimestamp = _buffer2String(
            pointCreateTimestamp.cast(), pointCreateTimestampSize);

        MXFileEntity entity = MXFileEntity(
            name: name,
            size: int.parse(size ?? "0"),
            createTimeStamp: int.parse(createTimestamp ?? "0"),
            lastTimeStamp: int.parse(lastTimestamp ?? "0"));
        _mxFileList.add(entity);

        calloc.free(charArray[0]);
        calloc.free(charArray[1]);
        calloc.free(charArray[2]);
        calloc.free(charArray[3]);

        calloc.free(charArray);
        calloc.free(sizeArray);
      }
      calloc.free(arrayArray);
      calloc.free(sizeArrayArray);
    }

    calloc.free(arrayPtr);
    calloc.free(sizeArrayPtr);
    return _mxFileList;
  }

  /// 查询指定目录下的日志文件信息(name/size/timestamp)。
  /// 注意：该接口目前未实现——Android直接返回空列表，iOS侧native符号也只是占位(始终返回0条)，
  /// 因此所有平台都会得到空列表；获取日志文件信息请使用[logFiles]
  /// Query the log files (name/size/timestamp) under the given directory.
  /// NOTE: currently not implemented — Android returns an empty list directly, and the
  /// iOS native symbol is only a stub (always yields 0 entries), so every platform gets
  /// an empty list; use [logFiles] to get log file metadata instead
  static List<Map<String, dynamic>> selectLogfiles(
      {required String directory}) {
    if (Platform.isIOS == false) return [];

    List<Map<String, dynamic>> logFiles = [];

    Pointer<Utf8> dirPtr = directory.toNativeUtf8();
    final arrayPtr = calloc<Pointer<Pointer<Utf8>>>();
    final sizeArrayPtr = calloc<Pointer<Uint32>>();
    final count = _selectLogfiles(dirPtr, arrayPtr, sizeArrayPtr);
    if (count > 0) {
      final array = arrayPtr[0];
      final sizeArray = sizeArrayPtr[0];

      for (int i = 0; i < count; i++) {
        final keyPtr = array[i];
        final size = sizeArray[i];
        String? logInfo = _buffer2String(keyPtr.cast(), size);
        if (logInfo != null) {
          List<String> _list = logInfo.split(",");
          Map<String, dynamic> _map = {
            "name": _list[0],
            "size": int.parse(_list[1]),
            "timestamp": int.parse(_list[2])
          };
          logFiles.add(_map);
        }
      }

      calloc.free(array);
      calloc.free(sizeArray);
    }

    calloc.free(dirPtr);
    calloc.free(arrayPtr);
    calloc.free(sizeArrayPtr);

    return logFiles;
  }

  /// 解析日志文件 返回日志内容列表
  /// diskcacheFilePath: 日志文件的完整路径
  /// cryptKey iv: 写入该文件时使用的加密参数 未加密不填
  /// 返回的每一项包含 name/tag/msg/level/timestamp/thread_id/is_main_thread/error_code，
  /// error_code为"1"表示该条数据解析失败(可能是cryptKey或iv不正确)，
  /// 返回顺序为时间倒序(最新的记录在前) 与iOS端selectWithDiskCacheFilePath一致
  /// Parse a log file and return its entries
  /// diskcacheFilePath: full path of the log file
  /// cryptKey / iv: the encryption params used when the file was written; omit for unencrypted files
  /// Each entry contains name/tag/msg/level/timestamp/thread_id/is_main_thread/error_code;
  /// error_code "1" means the entry failed to decode (possibly a wrong cryptKey or iv).
  /// Entries are returned newest first, consistent with iOS selectWithDiskCacheFilePath
  static List<Map<String, dynamic>> selectLogmsg(
      {required String diskcacheFilePath, String? cryptKey, String? iv}) {
    List<Map<String, dynamic>> logList = [];

    Pointer<Utf8> pathPtr = diskcacheFilePath.toNativeUtf8();
    Pointer<Utf8> cryptKeyPtr =
        cryptKey == null ? nullptr : cryptKey.toNativeUtf8();
    Pointer<Utf8> ivPtr = iv == null ? nullptr : iv.toNativeUtf8();

    final numberPtr = calloc<Int32>();
    final arrayPtr = calloc<Pointer<Pointer<Utf8>>>();
    final sizeArrayPtr = calloc<Pointer<Uint32>>();

    final result = _selectLogmsg(
        pathPtr, cryptKeyPtr, ivPtr, numberPtr, arrayPtr, sizeArrayPtr);
    final count = numberPtr.value;
    if (result == 0 && count > 0) {
      final array = arrayPtr[0];
      final sizeArray = sizeArrayPtr[0];
      for (int i = 0; i < count; i++) {
        String? json = _buffer2String(array[i].cast(), sizeArray[i]);
        if (json == null) continue;
        try {
          logList.add(Map<String, dynamic>.from(jsonDecode(json)));
        } catch (_) {}
      }

      /// native侧malloc的内存必须由native侧释放
      /// Memory malloc-ed on the native side must be freed by the native side
      _freeLogmsg(count, array, sizeArray);
    }

    calloc.free(pathPtr);
    if (cryptKeyPtr != nullptr) {
      calloc.free(cryptKeyPtr);
    }
    if (ivPtr != nullptr) {
      calloc.free(ivPtr);
    }
    calloc.free(numberPtr);
    calloc.free(arrayPtr);
    calloc.free(sizeArrayPtr);
    return logList;
  }

  /// 将native返回的UTF-8字节缓冲转为Dart字符串
  /// Convert a UTF-8 byte buffer returned from native code into a Dart string
  static String? _buffer2String(Pointer<Uint8>? ptr, int length) {
    if (ptr != null && ptr != nullptr) {
      var listView = ptr.asTypedList(length);
      return const Utf8Decoder().convert(listView);
    }
    return null;
  }

  String? _cryptKey;
  String? _iv;
  bool _enable = true;

  bool _shouldRemoveExpiredDataWhenEnterBackground = true;

  String? _nameSpace;
  String? _directory;

  /// loggerKey -> 实例注册表：destroy时据此找到并失效对应的Dart实例
  /// loggerKey -> instance registry; destroy uses it to locate and invalidate
  /// the matching Dart instances
  static final Map<String, MXLogger> _instanceMap = {};

  /// 失效当前实例：移除生命周期监听、关闭错误文件流并清空native句柄。
  /// 否则destroy之后App进入后台触发的清理回调会拿着已释放的native指针调用，
  /// 造成use-after-free崩溃
  /// Invalidate this instance: remove the lifecycle observer, close the error-file
  /// sink and clear the native handle. Without this, the enter-background cleanup
  /// callback would call into native code with a freed pointer after destroy,
  /// crashing with a use-after-free
  void _invalidate() {
    WidgetsBinding.instance.removeObserver(this);
    closeFailFile();
    _handle = nullptr;
    _enable = false;
  }
}

final DynamicLibrary _nativeLib = Platform.isAndroid
    ? DynamicLibrary.open("libmxlogger.so")
    : DynamicLibrary.process();

String _mxloggerFunction(String funcName) {
  return "flutter_mxlogger_" + funcName;
}

/// native函数: 初始化logger，返回logger句柄
/// Native function: initialize the logger and return its handle
final Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>,
        Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)
    _initialize = _nativeLib
        .lookup<
            NativeFunction<
                Pointer<Void> Function(
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Pointer<Utf8>)>>(_mxloggerFunction("initialize"))
        .asFunction();

/// native函数: 通过nameSpace+directory释放logger
/// (native侧返回void，此处声明须一致)
/// Native function: release the logger by nameSpace + directory
/// (the native side returns void, and the declaration here must match)
final void Function(Pointer<Utf8>, Pointer<Utf8>) _destroy = _nativeLib
    .lookup<
        NativeFunction<
            Void Function(
                Pointer<Utf8>, Pointer<Utf8>)>>(_mxloggerFunction("destroy"))
    .asFunction();

/// native函数: 通过loggerKey释放logger
/// Native function: release the logger by loggerKey
final void Function(Pointer<Utf8>) _destroyWithLoggerKey = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
        _mxloggerFunction("destroyWithLoggerKey"))
    .asFunction();

/// native函数: 通过logger句柄写入日志
/// 返回值声明为Int32与native的int严格匹配：原Uint64在32位设备上会多读一个
/// 垃圾寄存器，且负数错误码(-1/-2/-3)会被读成巨大正数
/// Native function: write a log entry via the logger handle.
/// The return type is Int32 to exactly match the native int: the previous Uint64 read
/// an extra garbage register on 32-bit devices, and negative error codes (-1/-2/-3)
/// came back as huge positive numbers
final int Function(
        Pointer<Void>, Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>) _log =
    _nativeLib
        .lookup<
            NativeFunction<
                Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32,
                    Pointer<Utf8>, Pointer<Utf8>)>>(_mxloggerFunction("log"))
        .asFunction();

/// native函数: 通过loggerKey写入日志 (返回值Int32与native的int严格匹配，理由同_log)
/// Native function: write a log entry via loggerKey
/// (the Int32 return exactly matches the native int, same rationale as _log)
final int Function(
        Pointer<Utf8>, Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>)
    _logLoggerKey = _nativeLib
        .lookup<
            NativeFunction<
                Int32 Function(
                    Pointer<Utf8>,
                    Pointer<Utf8>,
                    Int32,
                    Pointer<Utf8>,
                    Pointer<Utf8>)>>(_mxloggerFunction("log_loggerKey"))
        .asFunction();

/// native函数: 设置写入文件的日志等级
/// Native function: set the minimum level written to file
final void Function(Pointer<Void>, int) _setLevel = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
        _mxloggerFunction("set_level"))
    .asFunction();

/// native函数: 开启/禁用日志写入
/// Native function: enable or disable logging
final void Function(Pointer<Void>, int) _setEnable = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
        _mxloggerFunction("set_enable"))
    .asFunction();

// 控制台输出统一由flutter层debugPrint实现(native侧输出在初始化时已禁用)，
// 因此不再绑定native的set_console_enable，符号仍保留在native侧以兼容旧版本。
// Console output is handled by the Flutter layer's debugPrint (native output is
// disabled at initialization), so set_console_enable is no longer bound here;
// the native symbol is kept for backward compatibility.

/// native函数: 获取日志文件夹磁盘路径
/// Native function: get the disk path of the log directory
final Pointer<Int8> Function(Pointer<Void>) _getDiskcachePath = _nativeLib
    .lookup<NativeFunction<Pointer<Int8> Function(Pointer<Void>)>>(
        _mxloggerFunction("get_diskcache_path"))
    .asFunction();

/// native函数: 获取logger的唯一标识loggerKey
/// Native function: get the logger's unique key (loggerKey)
final Pointer<Int8> Function(Pointer<Void>) _getLoggerKey = _nativeLib
    .lookup<NativeFunction<Pointer<Int8> Function(Pointer<Void>)>>(
        _mxloggerFunction("get_loggerKey"))
    .asFunction();

/// native函数: 获取最近一次写入失败的错误信息
/// Native function: get the most recent write-error description
final Pointer<Int8> Function(Pointer<Void>) _getErrorDesc = _nativeLib
    .lookup<NativeFunction<Pointer<Int8> Function(Pointer<Void>)>>(
        _mxloggerFunction("get_error_desc"))
    .asFunction();

/// native函数: 释放get_loggerKey/get_diskcache_path/get_error_desc返回的native字符串
/// Native function: free the native strings returned by
/// get_loggerKey / get_diskcache_path / get_error_desc
final void Function(Pointer<Int8>) _freeString = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Int8>)>>(
        _mxloggerFunction("free_string"))
    .asFunction();

/// native函数: 设置日志文件最大存储时长(秒)
/// Native function: set the maximum age of log files in seconds
final void Function(Pointer<Void>, int) _setMaxDiskAge = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
        _mxloggerFunction("set_max_disk_age"))
    .asFunction();

/// native函数: 设置日志文件最大存储字节数(byte)
/// Native function: set the maximum total size of log files in bytes
final void Function(Pointer<Void>, int) _setMaxDiskSize = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>, Int32)>>(
        _mxloggerFunction("set_max_disk_size"))
    .asFunction();

/// native函数: 清理过期日志文件
/// Native function: remove expired log files
final void Function(Pointer<Void>) _removeExpireData = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
        _mxloggerFunction("remove_expire_data"))
    .asFunction();

/// native函数: 删除除当前正在写入文件之外的所有日志文件
/// Native function: remove all log files except the one currently being written
final void Function(Pointer<Void>) _removeBeforeAllData = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
        _mxloggerFunction("remove_before_all_data"))
    .asFunction();

/// native函数: 获取日志文件列表(文件名/大小/时间戳)
/// Native function: get the list of log files (name/size/timestamps)
final int Function(Pointer<Void>, Pointer<Pointer<Pointer<Pointer<Utf8>>>>,
        Pointer<Pointer<Pointer<Uint32>>>) _getLogfiles =
    _nativeLib
        .lookup<
                NativeFunction<
                    Int32 Function(
                        Pointer<Void>,
                        Pointer<Pointer<Pointer<Pointer<Utf8>>>>,
                        Pointer<Pointer<Pointer<Uint32>>>)>>(
            _mxloggerFunction("get_logfiles"))
        .asFunction();

/// native函数: 查询指定目录下的日志文件信息
/// (iOS侧该符号为未实现的占位 始终返回0条，见[MXLogger.selectLogfiles])
/// Native function: query the log files under the given directory
/// (the iOS symbol is an unimplemented stub that always yields 0 entries,
/// see [MXLogger.selectLogfiles])
final int Function(Pointer<Utf8>, Pointer<Pointer<Pointer<Utf8>>>,
        Pointer<Pointer<Uint32>>) _selectLogfiles =
    _nativeLib
        .lookup<
                NativeFunction<
                    Uint32 Function(
                        Pointer<Utf8>,
                        Pointer<Pointer<Pointer<Utf8>>>,
                        Pointer<Pointer<Uint32>>)>>(
            _mxloggerFunction("select_logfiles"))
        .asFunction();

/// native函数: 解析日志文件，返回日志条目
/// Native function: parse a log file and return its entries
final int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Int32>,
        Pointer<Pointer<Pointer<Utf8>>>, Pointer<Pointer<Uint32>>)
    _selectLogmsg = _nativeLib
        .lookup<
                NativeFunction<
                    Int32 Function(
                        Pointer<Utf8>,
                        Pointer<Utf8>,
                        Pointer<Utf8>,
                        Pointer<Int32>,
                        Pointer<Pointer<Pointer<Utf8>>>,
                        Pointer<Pointer<Uint32>>)>>(
            _mxloggerFunction("select_logmsg"))
        .asFunction();

/// native函数: 释放select_logmsg返回的native内存
/// Native function: free the native memory returned by select_logmsg
final void Function(int, Pointer<Pointer<Utf8>>, Pointer<Uint32>) _freeLogmsg =
    _nativeLib
        .lookup<
            NativeFunction<
                Void Function(Int32, Pointer<Pointer<Utf8>>,
                    Pointer<Uint32>)>>(_mxloggerFunction("free_logmsg"))
        .asFunction();

/// native函数: 删除所有日志文件
/// Native function: remove all log files
final void Function(Pointer<Void>) _removeAll = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
        _mxloggerFunction("remove_all"))
    .asFunction();

/// native函数: 获取存储的日志大小(byte)
/// 返回值Int32与两端native的int32_t严格匹配(上限约2GB，对日志足够)
/// Native function: get the total size of stored logs in bytes.
/// The Int32 return exactly matches the native int32_t on both platforms
/// (capped at ~2GB, plenty for logs)
final int Function(Pointer<Void>) _getLogSize = _nativeLib
    .lookup<NativeFunction<Int32 Function(Pointer<Void>)>>(
        _mxloggerFunction("get_log_size"))
    .asFunction();
