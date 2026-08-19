package com.dongjiayi.mxlogger;


import android.content.Context;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class MXLogger {

    static {
        System.loadLibrary("mxlogger");
    }

    /**
     * 是否开启控制台打印，默认不开启。开启控制台打印会影响写入效率，建议发布模式禁用 consoleEnable
     * <p>
     * Whether console printing is enabled, disabled by default. Console output hurts
     * write performance — disable it in release builds
     */
    private boolean consoleEnable;

    /**
     * 是否启用日志写入 默认true 与iOS/Flutter/C++核心的默认行为对齐
     * <p>
     * Whether logging is enabled, defaults to true — consistent with the iOS/Flutter/C++ core
     */
    private boolean enable = true;

    /**
     * 日志文件最大字节数 默认0 无限制
     * <p>
     * Maximum total size of log files in bytes, defaults to 0 (unlimited)
     */
    private long maxDiskSize;

    /**
     * 日志文件最大存储时长(秒) 默认0 无限制
     * <p>
     * Maximum age of log files in seconds, defaults to 0 (unlimited)
     */
    private long maxDiskAge;

    /**
     * 写入文件的日志等级 低于这个等级的日志不会被写入到文件，只可能被输出到控制台
     * <p>
     * Minimum level written to file; logs below this level are not written to disk
     * and can only appear in the console
     */
    private int level;

    /**
     * 磁盘缓存目录
     * <p>
     * Disk-cache directory of the log files
     */
    private String diskCachePath;

    /**
     * 当前日志文件大小(byte)
     * <p>
     * Current total size of stored logs in bytes
     */
    private long logSize;

    /**
     * nameSpace+diskCacheDirectory 做一次md5的值，唯一对应一个logger对象，可以通过这个操作logger对象。
     * 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)，
     * 但是你希望所有子模块(子组件)使用在主工程初始化的log，
     * 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过 {@link #log(String, String, int, String, String)} 进行日志写入
     * <p>
     * The md5 of nameSpace + diskCacheDirectory, uniquely identifying this logger instance.
     * Use case: in a large modularized app, sub-modules can share the logger initialized in
     * the main project by passing this key around (instead of the logger object) and writing
     * logs via {@link #log(String, String, int, String, String)} — keeping modules decoupled
     */
    private String loggerKey;

    /**
     * 完整构造方法：初始化logger并创建底层C++对象（其他构造方法最终都会调用它）
     * <p>
     * Designated constructor: initialize the logger and create the underlying C++ instance
     * (all other constructors funnel into this one)
     *
     * @param context            上下文 / Android context
     * @param nameSpace          日志命名空间 建议使用域名反转保证唯一性
     *                           / namespace of the log files; a reverse-domain name is recommended for uniqueness
     * @param diskCacheDirectory 日志初始化目录，为空时默认 /files/com.mxlog.LoggerCache
     *                           / log directory, defaults to /files/com.mxlog.LoggerCache when null
     * @param storagePolicy      文件存储策略 / log file storage policy
     * @param fileName           自定义文件名 默认为:mxlog / custom file name, defaults to "mxlog"
     * @param fileHeader         日志文件头信息，业务可以在初始化mxlogger的时候写入一些业务相关的信息
     *                           比如app版本 所属平台等等 文件创建的时候这条数据会被写入
     *                           / file header; the business layer can write context info (app version,
     *                           platform, etc.), written once when the file is created
     * @param cryptKey           AES-CFB-128 密钥，为空时不加密；16字节：超过16字节自动截断 不足16字节补0
     *                           / AES-CFB-128 encryption key, no encryption when null;
     *                           16 bytes: truncated if longer, zero-padded if shorter
     * @param iv                 AES-CFB-128 加密向量，为空时默认与cryptKey一致
     *                           / AES-CFB-128 initialization vector, defaults to cryptKey when null
     */
    public MXLogger(@NonNull Context context,
                    @NonNull String nameSpace,
                    @Nullable String diskCacheDirectory,
                    @Nullable MXStoragePolicyType storagePolicy,
                    @Nullable String fileName,
                    @Nullable String fileHeader,
                    @Nullable String cryptKey,
                    @Nullable String iv
                         ) {
        if(diskCacheDirectory == null){
            diskCacheDirectory = defaultDiskCacheDirectory(context);
        }

        /// storagePolicy标注为@Nullable，Java对null枚举做switch会直接抛NPE，必须先兜底为按天存储
        /// storagePolicy is annotated @Nullable and switching on a null enum throws an NPE
        /// in Java, so fall back to the daily policy first
        if(storagePolicy == null){
            storagePolicy = MXStoragePolicyType.YYYY_MM_DD;
        }

        String policy = "yyyy_MM_dd";
        switch (storagePolicy){
            case YYYY_MM:
                policy = "yyyy_MM";
                break;
            case YYYY_WW:
                policy = "yyyy_ww";
                break;
            case YYYY_MM_DD:
                policy = "yyyy_MM_dd";
                break;
            case YYYY_MM_DD_HH:
                policy = "yyyy_MM_dd_HH";
                break;
        }

        nativeHandle =  jniInitialize(nameSpace,diskCacheDirectory,policy,fileName,fileHeader,cryptKey,iv);

    }

    /**
     * 清理日志文件：先删除过期文件（最后修改时间超过maxDiskAge），若总大小仍超过maxDiskSize
     * 则从最旧的文件开始继续删除；当前正在写入的文件不会被删除。
     * Java层不会自动调用，需业务在合适的时机（如进入后台）主动触发
     * <p>
     * Clean up log files: first delete expired files (last-modified time older than
     * maxDiskAge), then, if the total size still exceeds maxDiskSize, keep deleting from
     * the oldest file onward; the file currently being written is never deleted.
     * Never called automatically on the Java side — trigger it at a suitable moment
     * (e.g. when the app enters background)
     */
   public void  removeExpireData(){
       native_removeExpireData(nativeHandle);
   }

    /**
     * 删除除当前正在写入文件之外的所有日志文件
     * <p>
     * Remove all log files except the one currently being written
     */
   public  void removeBeforeAllData(){
       native_removeBeforeAll(nativeHandle);
   }

    /**
     * 删除所有日志文件
     * <p>
     * Remove all log files
     */
  public  void  removeAll(){
      native_removeAll(nativeHandle);
  }

    /**
     * 写入debug等级日志
     * <p>
     * Write a debug-level log entry
     */
    public  int debug(@Nullable String tag, @Nullable String name, @Nullable String msg){
        return log(tag,0,name,msg);
    }

    /**
     * 写入info等级日志
     * <p>
     * Write an info-level log entry
     */
    public  int info(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,1,name,msg);
    }

    /**
     * 写入warn等级日志
     * <p>
     * Write a warn-level log entry
     */
    public  int warn(@Nullable String tag,@Nullable String name,@Nullable String msg){
        return log(tag,2,name,msg);
    }

    /**
     * 写入error等级日志
     * <p>
     * Write an error-level log entry
     */
    public  int error(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,3,name,msg);
    }

    /**
     * 写入fatal等级日志
     * <p>
     * Write a fatal-level log entry
     */
    public  int fatal(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,4,name,msg);
    }

    /**
     * 写入日志
     * <p>
     * Write a log entry
     *
     * @param tag   标记 / tag
     * @param level 日志等级 0:debug 1:info 2:warn 3:error 4:fatal
     *              / log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
     * @param name  日志名称 / logger name
     * @param msg   日志信息 / log message
     * @return 0 成功 -1 扩容失败 -2 解除映射失败 -3 映射失败（可调用 {@link #getErrorDesc()} 查看错误信息）
     *         / 0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
     *         (call {@link #getErrorDesc()} for details)
     */
    public  int log(@Nullable String tag,@Nullable int level,@Nullable String name,@Nullable String msg){

       return innerLog(tag,level,msg,name);
    }

    /**
     * 内部写入实现：判断是否在主线程后调用native方法，enable为false时直接返回0
     * <p>
     * Internal write implementation: detects whether the call is on the main thread,
     * then calls into native code; returns 0 immediately when logging is disabled
     */
    private  int innerLog(@Nullable String tag,@Nullable int level,@Nullable String msg,@Nullable String name){
        if(enable==false) return 0;
       boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
       return native_log(nativeHandle,name,level,msg,tag,isMainThread);
    }

    /**
     * 便捷构造方法：使用默认目录、按天存储、不加密初始化
     * <p>
     * Convenience constructor: default directory, daily storage policy, no encryption
     */
    public MXLogger(@NonNull Context context,@NonNull String nameSpace,@Nullable String fileHeader) {

        this(context,nameSpace,null,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,null,null);
    }

    /**
     * 便捷构造方法：使用默认目录、按天存储，并指定加密key和iv
     * <p>
     * Convenience constructor: default directory, daily storage policy,
     * with the given encryption key and iv
     */
    public MXLogger(@NonNull Context context,
                    @NonNull String nameSpace,
                    @Nullable String fileHeader,
                    @Nullable String cryptKey,
                    @Nullable String iv) {

        this(context,nameSpace,null,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,cryptKey,iv);
    }

    /**
     * 便捷构造方法：指定日志目录、按天存储、不加密初始化
     * <p>
     * Convenience constructor: custom directory, daily storage policy, no encryption
     */
    public MXLogger(@NonNull Context context,
                    @Nullable String fileHeader,
                    @NonNull String nameSpace,
                    @Nullable String diskCacheDirectory) {
        this(context,nameSpace,diskCacheDirectory,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,null,null);

    }

    /**
     * 设置是否开启控制台打印
     * <p>
     * Enable or disable console printing
     */
    public void setConsoleEnable(boolean consoleEnable) {
        this.consoleEnable = consoleEnable;
        native_consoleEnable(nativeHandle,consoleEnable);
    }

    /**
     * 控制台打印是否开启
     * <p>
     * Whether console printing is enabled
     */
    public boolean isConsoleEnable() {
        return consoleEnable;
    }


    /**
     * 获取写入文件的日志等级
     * <p>
     * Get the minimum level written to file
     */
    public int getLevel() {
        return level;
    }

    /**
     * 设置写入文件的日志等级：0:debug 1:info 2:warn 3:error 4:fatal，
     * 低于该等级的日志不会写入文件
     * <p>
     * Set the minimum level written to file: 0 debug, 1 info, 2 warn, 3 error, 4 fatal;
     * logs below this level are not written to disk
     */
    public void setLevel(int level) {
        this.level = level;
        native_level(nativeHandle,level);
    }

    /**
     * 日志写入功能是否开启
     * <p>
     * Whether logging is enabled
     */
    public boolean isEnable() {
        return enable;
    }

    /**
     * 设置是否开启日志写入功能，false时禁用日志
     * <p>
     * Enable or disable logging; pass false to disable
     */
    public void setEnable(boolean enable) {
        this.enable = enable;
    }

    /**
     * 获取日志文件最大字节数
     * <p>
     * Get the maximum total size of log files in bytes
     */
    public long getMaxDiskSize() {
        return maxDiskSize;
    }

    /**
     * 设置日志文件最大字节数(byte) 默认0 无限制，如 1024 * 1024 * 10 即10M；
     * 超限清理在调用 {@link #removeExpireData()} 时执行
     * <p>
     * Set the maximum total size of log files in bytes; defaults to 0 (unlimited),
     * e.g. 1024 * 1024 * 10 for 10 MB. The over-limit cleanup runs
     * when {@link #removeExpireData()} is called
     */
    public void setMaxDiskSize(long maxDiskSize) {
        this.maxDiskSize = maxDiskSize;
        native_maxDiskSize(nativeHandle,maxDiskSize);
    }

    /**
     * 获取日志文件最大存储时长(秒)
     * <p>
     * Get the maximum age of log files in seconds
     */
    public long getMaxDiskAge() {
        return maxDiskAge;
    }

    /**
     * 设置日志文件最大存储时长(秒) 默认0 无限制，如 60 * 60 * 24 * 7 即一个星期；
     * 以文件最后修改时间判断是否过期，过期文件在调用 {@link #removeExpireData()} 时删除
     * <p>
     * Set the maximum age of log files in seconds; defaults to 0 (unlimited),
     * e.g. 60 * 60 * 24 * 7 for one week. Expiry is judged by each file's last-modified
     * time, and expired files are deleted when {@link #removeExpireData()} is called
     */
    public void setMaxDiskAge(long maxDiskAge) {
        this.maxDiskAge = maxDiskAge;
        native_maxDiskAge(nativeHandle,maxDiskAge);
    }

    /**
     * 获取存储的日志大小(byte)
     * <p>
     * Get the total size of stored logs in bytes
     */
    public long getLogSize() {
        return native_logSize(nativeHandle);
    }

    /**
     * 获取日志文件磁盘缓存目录
     * <p>
     * Get the disk-cache directory of the log files
     */
    public String getDiskCachePath() {
        return native_diskcache_path(nativeHandle);
    }


    /**
     * 获取最近一次写入失败的错误信息
     * <p>
     * Get the description of the most recent write error
     */
    public  String getErrorDesc(){return  native_errorDesc(nativeHandle);}

    private final long nativeHandle;

    /**
     * 默认磁盘缓存目录: /files/com.mxlog.LoggerCache
     * <p>
     * Default disk-cache directory: /files/com.mxlog.LoggerCache
     */
    private  static  String defaultDiskCacheDirectory(@NonNull Context context){

        return userCacheDirectory(context) + "/com.mxlog.LoggerCache";
    }

    /**
     * 获取应用files目录的绝对路径
     * <p>
     * Get the absolute path of the app's files directory
     */
    private  static  String userCacheDirectory(@NonNull Context context){

        String cacheDir = context.getFilesDir().getAbsolutePath();
        return  cacheDir;
    }

    /**
     * 通过nameSpace+diskCacheDirectory销毁底层C++对象
     * <p>
     * Destroy the underlying C++ instance identified by nameSpace + diskCacheDirectory
     */
    public static void  destroy(@NonNull Context context, @NonNull String nameSpace,
                                @Nullable String diskCacheDirectory){
        if(diskCacheDirectory == null){
            diskCacheDirectory = defaultDiskCacheDirectory(context);
        }
        native_destroy(nameSpace,diskCacheDirectory);
    }

    /**
     * 通过loggerKey销毁底层C++对象
     * <p>
     * Destroy the underlying C++ instance identified by loggerKey
     */
    public static void  destroy(@NonNull String loggerKey){
        native_destroy_loggerKey(loggerKey);
    }

    /**
     * 获取logger的唯一标识loggerKey（nameSpace+diskCacheDirectory的md5值）
     * <p>
     * Get the logger's unique key (the md5 of nameSpace + diskCacheDirectory)
     */
    public String getLoggerKey() {
        return native_loggerKey(nativeHandle);
    }

    /**
     * 类方法：根据loggerKey获取已初始化的logger对象进行日志写入（适用于模块化场景，无需持有logger对象）。
     * 如果没有获取到logger对象 则调用这个方法没有任何反应 也不会报错
     * <p>
     * Class method: write a log entry via the loggerKey of an already-initialized logger
     * (for modularized apps, no logger instance needed).
     * If no logger matches the key, the call is a silent no-op — no error is thrown
     *
     * @param loggerKey logger的唯一标识 / unique key of the logger
     * @param tag       标记 / tag
     * @param level     日志等级 0:debug 1:info 2:warn 3:error 4:fatal
     *                  / log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
     * @param name      日志名称 / logger name
     * @param msg       日志信息 / log message
     * @return 0 成功 非0 失败 / 0 success, non-zero on failure
     */
    public static int log(@NonNull String loggerKey, @Nullable String tag,@NonNull int level,@Nullable String name,@Nullable String msg){
        boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
       return native_log_loggerKey(loggerKey,name,level,msg,tag,isMainThread);
    }

    /**
     * 获取存储的日志文件信息 每个元素为一个JSON字符串。
     * 字段: name(文件名) size(字节) last_timestamp(最后更新时间) create_timestamp(创建时间)
     * <p>
     * Get the metadata of stored log files; each element is a JSON string with fields:
     * name (file name), size (bytes), last_timestamp (last-modified time),
     * create_timestamp (creation time)
     */
    public String[] logFiles(){
        return native_logFiles(nativeHandle);
    }

    /**
     * 解析(解密)日志文件 每个元素为一条日志的JSON字符串 最新的记录在前(与iOS端对齐)。
     * 字段: name/msg/tag/level/timestamp/is_main_thread/thread_id/error_code
     * <p>
     * Parse (and decrypt) a log file; each element is one log entry as a JSON string,
     * newest first (consistent with iOS). Fields:
     * name/msg/tag/level/timestamp/is_main_thread/thread_id/error_code
     *
     * @param diskCacheFilePath 日志文件的完整路径 / full path of the log file
     * @param cryptKey          写入该文件时使用的加密key 未加密传null / the encryption key used
     *                          when the file was written, null for unencrypted files
     * @param iv                加密向量 / initialization vector
     */
    public static String[] selectWithFilePath(@NonNull String diskCacheFilePath,@Nullable String cryptKey,@Nullable String iv){
        return native_selectLogMsg(diskCacheFilePath,cryptKey,iv);
    }

    /**
     * native方法: 初始化logger 返回C++对象句柄
     * <p>
     * Native method: initialize the logger and return the C++ instance handle
     */
    private static native long jniInitialize(String nameSpace,String diskCacheDirectory,String storagePolicy,String fileName, String fileHeader, String cryptKey,String iv);

    /**
     * native方法: 通过句柄写入日志
     * <p>
     * Native method: write a log entry via the handle
     */
    private  static  native int native_log(long nativeHandle,String name,int level,String msg,String tag,boolean mainThread);

    /**
     * native方法: 通过loggerKey写入日志
     * <p>
     * Native method: write a log entry via loggerKey
     */
    private  static  native int native_log_loggerKey(String loggerKey,String name,int level,String msg,String tag,boolean mainThread);

    /**
     * native方法: 设置写入文件的日志等级
     * <p>
     * Native method: set the minimum level written to file
     */
    private  static  native  void  native_level(long nativeHandle,int level);

    /**
     * native方法: 开启/关闭native侧控制台输出
     * <p>
     * Native method: enable or disable native-side console output
     */
    private  static  native  void  native_consoleEnable(long nativeHandle,boolean enable);

    /**
     * native方法: 设置日志文件最大存储时长(秒)
     * <p>
     * Native method: set the maximum age of log files in seconds
     */
    private  static  native  void  native_maxDiskAge(long nativeHandle,long maxDiskAge);

    /**
     * native方法: 设置日志文件最大字节数(byte)
     * <p>
     * Native method: set the maximum total size of log files in bytes
     */
    private  static  native  void  native_maxDiskSize(long nativeHandle,long maxDiskSize);

    /**
     * native方法: 获取存储的日志大小(byte)
     * <p>
     * Native method: get the total size of stored logs in bytes
     */
    private static   native  long  native_logSize(long nativeHandle);

    /**
     * native方法: 获取日志文件磁盘缓存目录
     * <p>
     * Native method: get the disk-cache directory of the log files
     */
    private  static  native String native_diskcache_path(long nativeHandle);

    /**
     * native方法: 获取最近一次写入失败的错误信息
     * <p>
     * Native method: get the most recent write-error description
     */
    private  static  native  String native_errorDesc(long nativeHandle);

    /**
     * native方法: 清理过期日志文件
     * <p>
     * Native method: remove expired log files
     */
    private  static  native void native_removeExpireData(long nativeHandle);

    /**
     * native方法: 删除所有日志文件
     * <p>
     * Native method: remove all log files
     */
    private static  native  void  native_removeAll(long nativeHandle);

    /**
     * native方法: 删除除当前正在写入文件之外的所有日志文件
     * <p>
     * Native method: remove all log files except the one currently being written
     */
    private static  native  void  native_removeBeforeAll(long nativeHandle);

    /**
     * native方法: 获取logger的唯一标识loggerKey
     * <p>
     * Native method: get the logger's unique key (loggerKey)
     */
    private static native  String native_loggerKey(long nativeHandle);

    /**
     * native方法: 通过nameSpace+diskCacheDirectory销毁C++对象
     * <p>
     * Native method: destroy the C++ instance by nameSpace + diskCacheDirectory
     */
    private  static native  void native_destroy(String nameSpace,String diskCacheDirectory);

    /**
     * native方法: 通过loggerKey销毁C++对象
     * <p>
     * Native method: destroy the C++ instance by loggerKey
     */
    private static native void native_destroy_loggerKey(String loggerKey);

    /**
     * native方法: 获取日志文件列表 每个元素为一个JSON字符串
     * <p>
     * Native method: get the list of log files, each element as a JSON string
     */
    private static native String[] native_logFiles(long nativeHandle);

    /**
     * native方法: 解析(解密)日志文件 返回日志条目JSON字符串数组
     * <p>
     * Native method: parse (and decrypt) a log file, returning log entries as JSON strings
     */
    private static native String[] native_selectLogMsg(String diskCacheFilePath,String cryptKey,String iv);

}
