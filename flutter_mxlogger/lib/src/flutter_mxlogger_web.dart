

///日志文件存储策略
enum MXStoragePolicyType {
  yyyy_MM_dd,

  /// 按天存储 对应文件名: 2023-01-11_filename.mx
  yyyy_MM_dd_HH,

  /// 按小时存储 对应文件名: 2023-01-11-15_filename.mx
  yyyy_ww,

  /// 按周存储 对应文件名: 2023-01-02w_filename.mx（02w是指一年中的第2周）
  yyyy_MM

  /// 按月存储 对应文件名: 2023-01_filename.mx
}

class MXFileEntity {
  late String? name;

  /// 文件名
  late int size;

  /// 文件大小(byte)
  late int createTimeStamp;

  /// 文件创建时间
  late int lastTimeStamp;

  /// 文件最后修改时间

  DateTime get createTime =>
      DateTime.fromMillisecondsSinceEpoch(createTimeStamp * 1000);

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

class MXLogger {


  bool get enable => _enable;

  /// 获取写入日志的错误数据 当[log]方法 !=0 的时候。
  String? get errorDesc => _errorDesc();

  /// 获取日志文件夹的磁盘路径(directory+nameSpace)
  String get diskcachePath => getDiskcachePath();

  /// 获取错误文件路径
  String get diskcacheErrorPath => diskcachePath + "/error.txt";

  /// 获取日志底层的唯一标识 可以通过这个key操作日志对象
  /// 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)
  /// 但是你希望所有子模块(子组件)使用在主工程初始化的log，
  /// 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey 进行日志写入
  String? get loggerKey => getLoggerKey();

  /// 获取存储的日志大小 (byte)
  int get logSize => getLogSize();

  /// 获取日志文件列表
  List<MXFileEntity> get logFiles => getLogFiles();

  String? get cryptKey => _cryptKey;

  String? get iv => _iv;



  /// 使用自定义路径初始化MXLogger
  /// nameSpace: 日志文件的命名空间建议使用域名反转保证唯一性
  /// directory: 自定义日志文件路径
  /// storagePolicy: 日志文件存储策略
  /// fileName: 自定义文件名
  /// fileHeader:日志文件头信息，业务可以在初始化mxlogger的时候 写入一些业务相关的信息 比如app版本 所属平台等等 文件创建的时候这条数据会被写入
  /// cryptKey:  如果日志信息需要加密需要填入这个值 应为正好为16个英文字母
  /// iv: 如果不填默认和cryptKey一致
  MXLogger(
      {required String nameSpace,
        required String directory,
        MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyy_MM_dd,
        String? fileName,
        String? fileHeader,
        String? cryptKey,
        String? iv}) {
    _cryptKey = cryptKey;
    _iv = iv;

  }

  /// 初始化MXLogger
  /// nameSpace: 日志文件的命名空间建议使用域名反转保证唯一性
  /// directory: 自定义日志文件路径
  /// storagePolicy: 日志文件存储策略
  /// 默认路径 ios:/Library/com.mxlog.LoggerCache/nameSpace
  ///         android: /files/com.mxlog.LoggerCache/nameSpace
  /// fileName: 自定义文件名 默认值 log
  /// fileHeader:日志文件头信息，业务可以在初始化mxlogger的时候 写入一些业务相关的信息 比如app版本 所属平台等等 文件创建的时候这条数据会被写入
  /// cryptKey:  如果日志信息需要加密需要填入这个值 应为正好为16个英文字母
  /// iv: 如果不填默认和cryptKey一致
  static Future<MXLogger> initialize(
      {required String nameSpace,
        String? directory,
        MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyy_MM_dd,
        String? fileName,
        String? fileHeader,
        String? cryptKey,
        String? iv}) async {
    String ns = nameSpace;
    String dr = directory ?? "";


    MXLogger mxLogger = MXLogger(
        nameSpace: ns,
        directory: dr,
        storagePolicy: storagePolicy,
        fileName: fileName,
        fileHeader: fileHeader,
        cryptKey: cryptKey,
        iv: iv);

    return mxLogger;
  }

  /// 释放log
  static void destroy({required String nameSpace, String? directory}) {

  }

  /// 通过key 释放log对象
  static void destroyWithLoggerKey(String loggerKey) {

  }

  /// 类方法 使用 mapKey操作日志
  static void logLoggerKey(String? loggerKey, int lvl, String msg,
      {String? name, String? tag}) {

  }

  /// 类方法 方便调用
  static void debugLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 0, msg, name: name, tag: tag);
  }

  static void infoLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 1, msg, name: name, tag: tag);
  }

  static void warnLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 2, msg, name: name, tag: tag);
  }

  static void errorLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 3, msg, name: name, tag: tag);
  }

  static void fatalLog(String? loggerKey, String msg,
      {String? name, String? tag}) {
    logLoggerKey(loggerKey, 4, msg, name: name, tag: tag);
  }

  /// 程序进入后台的时候是否去清理过期文件 默认为YES
  void shouldRemoveExpiredDataWhenEnterBackground(bool should) {

  }

  /// 设置写入日志文件等级
  ///    0:debug
  ///     1:info
  ///     2:warn
  ///     3:error
  ///     4:fatal
  ///    lvl=0 >=0 的等级会被写入日志
  ///    lvl=1 >=1 的等级会被写入日志
  ///    lvl=2 >=2 的等级被毁写入日志
  ///    .......
  void setLevel(int lvl) {
    if (enable == false) return;

  }

  /// 设置是否禁用日志写入功能
  void setEnable(bool enable) {
    _enable = enable;

  }

  /// 设置是否禁用控制台输出功能，
  /// 注意:1.这个方法只是禁用了控制台的输出和打印，并不影响日志的文件的写入
  ///     2.在测试环境或者debug状态的时候可以开启console,但是app上线建议关掉。生产环境这种性能损耗毫无意义。
  void setConsoleEnable(bool e) {
    if (enable == false) return;

  }

  /// 设置日志文件存储最大时长(s) 默认为0 不限制   60 * 60 *24 *7； 即一个星期
  void setMaxDiskAge(int age) {
    if (enable == false) return;

  }

  /// 设置日志文件存储最大字节数(byte) 默认为0 不限制 1024 * 1024 * 10; 即10M
  void setMaxDiskSize(int size) {
    if (enable == false) return;

  }

  /// 删除过期文件
  void removeExpireData() {
    if (enable == false) return;

  }

  /// 删除除当前正在写入的所有日志文件
  void removeBeforeAllData() {
    if (enable == false) return;

  }

  /// 删除所有日志文件
  void removeAll() {
    if (enable == false) return;

  }

  /// 获取存储的日志大小 (byte)
  int getLogSize() {
    if (enable == false) return 0;
    return 0;
  }

  /// 获取日志文件夹的存储路径
  String getDiskcachePath() {
    if (enable == false) return "";

    return "";
  }

  String? _errorDesc() {
    if (enable == false) return null;

    return null;
  }

  /// 获取日志底层的唯一标识 可以通过这个key操作日志对象
  /// 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)
  /// 但是你希望所有子模块(子组件)使用在主工程初始化的log，
  /// 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey 进行日志写入
  String? getLoggerKey() {

    return null;
  }

  int debug(String msg, {String? name, String? tag}) {
    return log(0, msg, name: name, tag: tag);
  }

  int info(String msg, {String? name, String? tag}) {
    return log(1, msg, name: name, tag: tag);
  }

  int warn(String msg, {String? name, String? tag}) {
    return log(2, msg, name: name, tag: tag);
  }

  int error(String msg, {String? name, String? tag}) {
    return log(3, msg, name: name, tag: tag);
  }

  int fatal(String msg, {String? name, String? tag}) {
    return log(4, msg, name: name, tag: tag);
  }

  /// 当返回值不等于0的时候 开发者可以调用[writeFail] 方法写入错误信息到本地。
  int log(int lvl, String msg, {String? name, String? tag}) {
    if (enable == false) return 0;


    return 0;
  }

  /// call  when log return value != 0.
  /// code: [log] return value
  /// errorDesc: [mxlogger.errorDesc]
  /// other: business
  void writeFail(
      {required int code, required String errorDesc, String? other}) {

  }

  void deleteFailFile() {

  }

  void closeFailFile() {

  }

  List<MXFileEntity> getLogFiles() {

    return [];
  }

  /// 目前只对 ios端生效
  static List<Map<String, dynamic>> selectLogfiles(
      {required String directory}) {


    return [];
  }



  String? _cryptKey;
  String? _iv;
  bool _enable = true;

}
