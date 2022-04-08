
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'flutter_mx_console.dart';

typedef LoggerFunction = Void Function(
    Pointer<Int8>, Pointer<Int8>, Pointer<Int8>);

typedef FlutterLogFunction = void Function(
    Pointer<Int8>, Pointer<Int8>, Pointer<Int8>);


class MXLogger {
  static final ConsoleLog _consoleLog = ConsoleLog();
  static bool _consoleEnable = false;

  static bool _enable = true;

  static bool? _isTracking;

  static bool _isEnable(){

    return   _enable == true;
  }
  ///不调这个方法也行 一切都有默认值
  static void initialize({String? nameSpace, String? directory}) {
   if(_isEnable() == false) return;

    String ns = nameSpace ?? "default";
    Pointer<Utf8> nsPtr = ns.toNativeUtf8();
    Pointer<Utf8> directoryPtr =
        directory == null ? nullptr : directory.toNativeUtf8();

    _initWithNamespace(nsPtr, directoryPtr);
    calloc.free(nsPtr);
    calloc.free(directoryPtr);
  }

  /// 设置写入日志文件等级
  ///    0:debug
  ///     1:info
  ///     2:warn
  ///     3:error
  ///     4:fatal
  static void setFileLevel(int lvl) {
    if(_isEnable() == false) return;
    _setFileLevel(lvl);
  }
  static void setConsoleLevel(int lvl){
    _consoleLog.level = lvl;
  }

  /// 设置文件名
  static void setFileName(String fileName){
    if(_isEnable() == false) return;
    Pointer<Utf8> fileNamePtr = fileName.toNativeUtf8();
    _setFileHeader(fileNamePtr);
    calloc.free(fileNamePtr);
  }
  /// 程序进入后台的时候是否清理过期文件 默认 YES
  static void shouldRemoveExpiredDataWhenEnterBackground(bool should) {
    if(_isEnable() == false) return;
    _shouldRemoveExpiredDataWhenEnterBackground(should == true ? 1 : 0);
  }

  /// 是否在程序退出的的时候清理过期文件 默认YES
  static void shouldRemoveExpiredDataWhenTerminate(bool should) {
    if(_isEnable() == false) return;
    _shouldRemoveExpiredDataWhenTerminate(should == true ? 1 : 0);
  }

  /// 设置是否禁用日志写入功能
  static void setFileEnable(bool enable) {
    if(_isEnable() == false) return;
    _setFileEnable(enable == true ? 1 : 0);
  }

  static void setConsoleEnable(bool enable){
    _consoleEnable =  enable;
  }
  /// 设置文件头
  static void setFileHeader(String header) {
    if(_isEnable() == false) return;
    Pointer<Utf8> headerPtr = header.toNativeUtf8();
    _setFileHeader(headerPtr);
    calloc.free(headerPtr);
  }

  /// 设置日志文件存储最大时长(s) 默认为0 不限制   60 * 60 *24 *7 即一个星期
  static void setMaxdiskAge(int age) {
    if(_isEnable() == false) return;
    _setMaxdiskAge(age);
  }

  /// 设置日志文件存储最大字节数(byte) 默认为0 不限制 1024 * 1024 * 10; 即10M
  static void setMaxdiskSize(int size) {
    if(_isEnable() == false) return;
    _setMaxdiskSize(size);
  }

  /// 删除过期文件
  static void removeExpireData() {
    if(_isEnable() == false) return;
    _removeExpireData();
  }

  /// 删除所有日志文件
  static void removeAll() {
    if(_isEnable() == false) return;
    _removeAll();
  }
  static void setEnable(bool enable){
    _enable = enable;

  }

  ///
  /// 日志文件存储策略
  /// yyyy_MM_dd 每天存储一个日志文件
  /// yyyy_ww    每周存储一个日志文件
  /// yyyy_MM  每个月存储一个日志文件
  /// yyyy_MM_dd_HH 每小时存储一个日志文件

  /// 默认值: yyyy_MM_dd
  ///
  static void setStoragePolicy(String policy) {
    if(_isEnable() == false) return;
    Pointer<Utf8> policyPtr = policy.toNativeUtf8();
    _setStoragePolicy(policyPtr);
    calloc.free(policyPtr);
  }

  /// 获取存储的日志大小 (byte)
  static int logSize() {
    if(_isEnable() == false) return 0;
    return _getLogSize();
  }

  /// 写入文件格式化  默认 [%d][%t][%p]%m
  static void setFilePattern(String pattern) {
    if(_isEnable() == false) return;
    Pointer<Utf8> patternPtr = pattern.toNativeUtf8();
    _setFilePattern(patternPtr);
    calloc.free(patternPtr);
  }
  static void setConsolePattern(String pattern){
    _consoleLog.pattern = pattern;
  }

  /// 设置写入日志文件同步还是异步
  static void setAsync(bool isAsync){
    _setAsync(isAsync == true ? 1 : 0);
  }

  /// 是否正在debuging
  static bool isDebugTraceing() {
    if(_isEnable() == false) return true;
    if(_isTracking != null) return _isTracking!;

   bool  isTracking = _isDebugTracking() == 1 ? true : false;
    _isTracking =  isTracking;
    return  isTracking;
  }

  static String? getdDiskcachePath() {
    if(_isEnable() == false) return null;
    Pointer<Int8> result = _getdDiskcachePath();
    String path =  result.cast<Utf8>().toDartString();
    return path;
  }

  static void debug(String msg, {bool? isAsync, String? name, String? tag}) {

    log(0, msg,isAsync: isAsync, name: name, tag: tag);
  }

  static void info(String msg, {bool? isAsync, String? name, String? tag}) {

    log(1, msg, isAsync: isAsync,name: name, tag: tag);
  }

  static void warn(String msg, {bool? isAsync, String? name, String? tag}) {

    log(2, msg, isAsync: isAsync,name: name, tag: tag);
  }

  static void error(String msg, {bool? isAsync,String? name, String? tag}) {

    log(3, msg, isAsync: isAsync,name: name, tag: tag);
  }

  static void fatal(String msg, {bool? isAsync,String? name, String? tag}) {

    log(4, msg, isAsync: isAsync,name: name, tag: tag);
  }

  /// 写入日志文件默认为异步，可以通过 setAsync 或者设置  isAsync == false 为同步
  static void log(int lvl, String msg, {bool? isAsync, String? name, String? tag}) {
    if (_isEnable() == false) return;

    if(_consoleEnable == true && isDebugTraceing() == true ){

       _consoleLog.log(lvl, msg, name: name, tag: tag);
    }


    Pointer<Utf8> namePtr = name != null ? name.toNativeUtf8() : nullptr;
    Pointer<Utf8> tagPtr = tag != null ? tag.toNativeUtf8() : nullptr;
    if(isAsync == null){
      _log(namePtr, lvl, msg.toNativeUtf8(), tagPtr);
    }
    if(isAsync == true){
      _asyncLogFile(namePtr, lvl, msg.toNativeUtf8(), tagPtr);
    }
    if(isAsync == false){
      _syncLogFile(namePtr, lvl, msg.toNativeUtf8(), tagPtr);
    }


    calloc.free(namePtr);
    calloc.free(tagPtr);
  }
}

final DynamicLibrary _nativeLib = DynamicLibrary.process();

String _mxlogger_function(String funcName) {
  return "flutter_mxlogger_" + funcName;
}

///初始化logger
final int Function(Pointer<Utf8>, Pointer<Utf8>) _initWithNamespace = _nativeLib
    .lookup<NativeFunction<Int8 Function(Pointer<Utf8>, Pointer<Utf8>)>>(
    _mxlogger_function("initWithNamespace"))
    .asFunction();

final void Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>) _log =
    _nativeLib
        .lookup<
            NativeFunction<
                Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>,
                    Pointer<Utf8>)>>(_mxlogger_function("log"))
        .asFunction();


final void Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>) _asyncLogFile =
_nativeLib
    .lookup<
    NativeFunction<
        Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>,
            Pointer<Utf8>)>>(_mxlogger_function("async_log_file"))
    .asFunction();


final void Function(int) _setAsync =
_nativeLib
    .lookup<
    NativeFunction<
        Void Function(Int32)>>(_mxlogger_function("set_is_async"))
    .asFunction();

final void Function(Pointer<Utf8>, int, Pointer<Utf8>, Pointer<Utf8>) _syncLogFile =
_nativeLib
    .lookup<
    NativeFunction<
        Void Function(Pointer<Utf8>, Int32, Pointer<Utf8>,
            Pointer<Utf8>)>>(_mxlogger_function("sync_log_file"))
    .asFunction();

final void Function(int) _setFileLevel = _nativeLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    _mxlogger_function("set_file_level"))
    .asFunction();

final void Function(int) _setFileEnable = _nativeLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    _mxlogger_function("set_file_enable"))
    .asFunction();

final void Function(Pointer<Utf8>) _setFileHeader = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
    _mxlogger_function("set_file_header"))
    .asFunction();

final void Function(Pointer<Utf8>) _setFileName = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
    _mxlogger_function("set_file_name"))
    .asFunction();

final Pointer<Int8> Function() _getdDiskcachePath = _nativeLib
    .lookup<NativeFunction<Pointer<Int8> Function()>>(
    _mxlogger_function("get_diskcache_path"))
    .asFunction();

final void Function(int) _shouldRemoveExpiredDataWhenEnterBackground =
    _nativeLib
        .lookup<NativeFunction<Void Function(Int32)>>(
        _mxlogger_function("set_remove_exporeddata_background"))
        .asFunction();

final void Function(int) _shouldRemoveExpiredDataWhenTerminate = _nativeLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    _mxlogger_function("set_remove_exporeddata_terminate"))
    .asFunction();

final void Function(int) _setMaxdiskAge = _nativeLib
    .lookup<NativeFunction<Void Function(Int32)>>(
    _mxlogger_function("set_max_disk_age"))
    .asFunction();

final void Function(int) _setMaxdiskSize = _nativeLib
    .lookup<NativeFunction<Void Function(Uint64)>>(
    _mxlogger_function("set_max_disk_size"))
    .asFunction();

final void Function(Pointer<Utf8>) _setStoragePolicy = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
    _mxlogger_function("set_storage_policy"))
    .asFunction();

final void Function(Pointer<Utf8>) _setFilePattern = _nativeLib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>(
    _mxlogger_function("set_file_pattern"))
    .asFunction();

final void Function() _removeExpireData = _nativeLib
    .lookup<NativeFunction<Void Function()>>(
    _mxlogger_function("remove_expire_data"))
    .asFunction();

final void Function() _removeAll = _nativeLib
    .lookup<NativeFunction<Void Function()>>(
    _mxlogger_function("remove_all"))
    .asFunction();

final int Function() _getLogSize = _nativeLib
    .lookup<NativeFunction<Uint64 Function()>>(
    _mxlogger_function("get_log_size"))
    .asFunction();

final int Function() _isDebugTracking = _nativeLib
    .lookup<NativeFunction<Int32 Function()>>(
    _mxlogger_function("is_debug_tracking"))
    .asFunction();
