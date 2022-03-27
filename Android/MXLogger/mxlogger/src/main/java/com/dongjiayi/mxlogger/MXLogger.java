package com.dongjiayi.mxlogger;

import android.content.Context;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import javax.crypto.interfaces.PBEKey;

public class MXLogger {
    private static @NonNull String defaultDiskCacheDirectory;

    /**
     * 日志所在磁盘路径
     * */
    private static   @NonNull String diskCachePath;

    /**
     日志文件存储策略
     yyyy_MM_dd 每天存储一个日志文件
     yyyy_ww    每周存储一个日志文件
     yyyy_MM  每个月存储一个日志文件
     yyyy_MM_dd_HH 每小时存储一个日志文件

     默认值: yyyy_MM_dd
     **/

    private static @NonNull String storagePolicy;

    /**
     %d 日志生成时间
     %p 日志等级
     %t 线程id
     %m 日志信息 msg
     %a tag
     默认: 控制台输出格式化  [%d][%p]%m
     */

    private static @NonNull String consolePattern;
    /**
     * 默认 写入文件格式化  [%d][%t][%p]%m
     * */
    private static @NonNull String filePattern;
    /**
        参数：
         0:debug
        1:info
        2:warn
         3:error
        4:fatal
     设置控制台输出等级
    **/
    private static int consoleLevel;
 /**
  * 写入文件日志设置等级
  * */
    private static  int fileLevel;


    /**
   * 开启/禁用控制台日志输出
   *  默认情况下 如果当前设备连接AndroidStudio正在调试，那么 consoleEnable = YES，
   *  会在控制台输出日志。非调试状态下不会把日志输出到控制台
  * */
    private static boolean consoleEnable;
 /**
  * 开启/禁用日志写入 默认YES
  * */
    private static boolean fileEnable;

    /**
  设置文件名，配合storagePolicy字段，如果 fileName =@"appname" storagePolicy = @“yyyy_MM_dd”
 那么最终存储的文件名为 appname_2022-03-15.log

 默认值:mxlog
 **/
    private static String fileName;

    /** 设置每次创建文件的时候 写入的文件头信息 比如可以把当前设备型号，用户信息等等 写进去*/
    private static String fileHeader;
    /**
     * 初始化MXLogger
     * */
   public  static  void  initialize(Context context){
      initWithNamespace(context,"mxlog");
   }
   public  static  void initWithNamespace(Context context,@NonNull String nameSpace){
       initWithNamespace(context,nameSpace,null);
   }
    public  static void initWithNamespace(Context context,@NonNull String nameSpace, @Nullable String directory){
        System.loadLibrary("mxlogger");
      if (directory == null){
          directory = defaultDiskCacheDirectory(context);
      }
      diskCachePath = directory + "/" + nameSpace + "/";
      jniInitialize(diskCachePath);
    }


    public  static void debug(@Nullable String msg){
       debug(null,msg);
    }

    public  static void info(@Nullable String msg){
        info(null,msg);
    }

    public  static void warn(@Nullable String msg){
        warn(null,msg);
    }
    public  static void error(@Nullable String msg){
        error(null,msg);
    }

    public  static void fatal(@Nullable String msg){
      fatal(null,msg);
    }



    public  static void debug(@Nullable String tag,@Nullable String msg){
        debug(null,tag,msg);
    }

    public  static void info(@Nullable String tag,@Nullable String msg){
        info(null,tag,msg);
    }

    public  static void warn(@Nullable String tag,@Nullable String msg){
        warn(null,tag,msg);
    }
    public  static void error(@Nullable String tag,@Nullable String msg){
        error(null,tag,msg);
    }

    public  static void fatal(@Nullable String tag,@Nullable String msg){
        fatal(null,tag,msg);
    }




    public  static void debug(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,0,tag,msg);
    }

    public  static void info(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,1,tag,msg);
    }

    public  static void warn(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,2,tag,msg);
    }
    public  static void error(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,3,tag,msg);
    }

    public  static void fatal(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,4,tag,msg);
    }


    public static  void log(@Nullable String name,@NonNull int level,@Nullable String tag,@Nullable String msg){
        innerLog(0,name,level,msg,tag);
    }


    /**
     * 设置默认存储目录
     * */
    private static  String defaultDiskCacheDirectory(Context context){
            if (defaultDiskCacheDirectory == null){
                defaultDiskCacheDirectory = userCacheDirectory(context) + "/com.mxlog.LoggerCache";
            }
            return defaultDiskCacheDirectory;
    }
    private static String userCacheDirectory(Context context){
        return context.getFilesDir().getAbsolutePath();
    }

    private   static  void innerLog(int logType,String name,int level,String msg,String tag){

       boolean mainThread = Looper.myLooper() == Looper.getMainLooper();

        log(logType,name,level,msg,tag,mainThread);
    }




    @NonNull
    public static String getStoragePolicy() {
        return storagePolicy;
    }

    public static void setStoragePolicy(@NonNull String storagePolicy) {
        native_storagePolicy(storagePolicy);
        MXLogger.storagePolicy = storagePolicy;
    }


    @NonNull
    public static String getDiskCachePath() {
        return diskCachePath;
    }

    @NonNull
    public static String getConsolePattern() {
        return consolePattern;
    }

    public static void setConsolePattern(@NonNull String consolePattern) {
        native_consolePattern(consolePattern);
        MXLogger.consolePattern = consolePattern;
    }

    @NonNull
    public static String getFilePattern() {
        return filePattern;
    }

    public static void setFilePattern(@NonNull String filePattern) {
        native_filePattern(filePattern);
        MXLogger.filePattern = filePattern;
    }

    public static int getConsoleLevel() {
        return consoleLevel;
    }

    public static void setConsoleLevel(int consoleLevel) {
        native_consoleLevel(consoleLevel);
        MXLogger.consoleLevel = consoleLevel;
    }

    public static int getFileLevel() {
        return fileLevel;
    }

    public static void setFileLevel(int fileLevel) {
        native_fileLevel(fileLevel);
        MXLogger.fileLevel = fileLevel;
    }
    public static boolean isConsoleEnable() {
        return consoleEnable;
    }

    public static void setConsoleEnable(boolean consoleEnable) {
        native_consoleEnable(consoleEnable);
        MXLogger.consoleEnable = consoleEnable;
    }

    public static boolean isFileEnable() {
        return fileEnable;
    }

    public static void setFileEnable(boolean fileEnable) {
        native_fileEnable(fileEnable);
        MXLogger.fileEnable = fileEnable;
    }
    public static String getFileName() {
        return fileName;
    }

    public static void setFileName(String fileName) {
        native_fileName(fileName);
        MXLogger.fileName = fileName;
    }

    public static String getFileHeader() {
        return fileHeader;
    }

    public static void setFileHeader(String fileHeader) {
        native_fileHeader(fileHeader);
        MXLogger.fileHeader = fileHeader;
    }
    private static native String version();
   /**
   * 初始化日志文件目录
   */
   private  static  native  void jniInitialize(String diskCachePath);

   private  static  native  void log(int logType,String name,int level,String msg,String tag,boolean mainThread);


   private  static  native void native_storagePolicy(String policy);
   private  static  native void native_consolePattern(String pattern);
   private  static  native void native_filePattern(String pattern);
   private  static  native void native_consoleLevel(int level);
   private  static  native void native_fileLevel(int level);
   private  static  native void native_fileEnable(boolean enable);
   private  static  native void native_consoleEnable(boolean enable);
   private  static  native void native_fileName(String fileName);
   private  static  native void native_fileHeader(String fileHeader);
}
