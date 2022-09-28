package com.dongjiayi.mxlogger;


import android.content.Context;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class MXLogger {

    /**
  * 是否开启控制台打印，默认不开启, 开始控制台打印会影响 写入效率 ，建议发布模式禁用 consoleEnable
  * */
  public boolean consoleEnable;

    /**
  * 禁用日志 默认false;
  * */
  public boolean enable;

    /**
   * 日志文件最大字节数 默认0 无限制
   * */
  public long maxDiskSize;

  /**
   * 日志文件最大存储时长 默认0 无限制
   * */
  public  long maxDiskAge;
    /**
   * 设置写入文件日志等级 低于这个等级的日志不会被写入到文件，只可能被输出到控制台
   * */
  public int fileLevel;

    /**
     * 获取磁盘缓存目录
     * */
  public String diskCachePath;
    /**
   * 获取当前日志文件大小
   * */
  public  long logSize;

 /**
  * nameSpace 日志命名空间 建议使用域名反转保证唯一性
  * diskCacheDirectory 日志初始化目录
  * storagePolicy 文件存储策略
  * fileName 自定义文件名
  * cryptKey aesCFB128 秘钥
  * iv aesCFB128 iv
  * */
    public MXLogger(@NonNull Context context, @NonNull String nameSpace,
                    @Nullable String diskCacheDirectory,
                    @Nullable String storagePolicy,
                    @Nullable String fileName,
                    @Nullable String cryptKey,
                    @Nullable String iv
                         ) {
        if(diskCacheDirectory == null){
            diskCacheDirectory = defaultDiskCacheDirectory(context);
        }
        System.loadLibrary("mxlogger");
        nativeHandle =  jniInitialize(nameSpace,diskCacheDirectory,storagePolicy,fileName,cryptKey,iv);

    }

   public void  removeExpireData(){
       native_removeExpireData(nativeHandle);
   }

  public  void  removeAll(){
      native_removeAll(nativeHandle);
  }
    public  void debug(@Nullable String tag, @Nullable String name, @Nullable String msg){
        log(tag,0,name,msg);
    }
    public  void info(@Nullable String tag,@Nullable String name,@Nullable String msg){
        log(tag,1,name,msg);
    }
    public  void warn(@Nullable String tag,@Nullable String name,@Nullable String msg){
        log(tag,2,name,msg);
    }
    public  void error(@Nullable String tag,@Nullable String name,@Nullable String msg){
        log(tag,3,name,msg);
    }
    public  void fatal(@Nullable String tag,@Nullable String name,@Nullable String msg){
        log(tag,4,name,msg);
    }
    /**
     * tag 标记
     * level 0_debug 1_info 2_warn 3_error 4_fatal
     * name name
     * msg 日志信息
    * */
    public  void log(@Nullable String tag,@Nullable int level,@Nullable String name,@Nullable String msg){

        innerLog(tag,level,msg,name);
    }
    private  void innerLog(@Nullable String tag,@Nullable int level,@Nullable String msg,@Nullable String name){
        if(enable) return;
       boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
        native_log(nativeHandle,name,level,msg,tag,isMainThread);
    }

    public MXLogger(@NonNull Context context,@NonNull String nameSpace) {

        this(context,nameSpace,null,null,null,null,null);
    }

    public MXLogger(@NonNull Context context,@NonNull String nameSpace,
                    @Nullable String cryptKey,
                    @Nullable String iv) {
        this(context,nameSpace,null,null,null,cryptKey,iv);
    }

    public MXLogger(@NonNull Context context,@NonNull String nameSpace,
                    @Nullable String diskCacheDirectory) {
        this(context,nameSpace,diskCacheDirectory,null,null,null,null);

    }

    public void setConsoleEnable(boolean consoleEnable) {
        this.consoleEnable = consoleEnable;
        native_consoleEnable(nativeHandle,consoleEnable);
    }

    public boolean isConsoleEnable() {
        return consoleEnable;
    }


    public int getFileLevel() {
        return fileLevel;
    }

    public void setFileLevel(int fileLevel) {
        this.fileLevel = fileLevel;
        native_fileLevel(nativeHandle,fileLevel);
    }

    public boolean isEnable() {
        return enable;
    }

    public void setEnable(boolean enable) {
        this.enable = enable;
    }

    public long getMaxDiskSize() {
        return maxDiskSize;
    }

    public void setMaxDiskSize(long maxDiskSize) {
        this.maxDiskSize = maxDiskSize;
        native_maxDiskSize(nativeHandle,maxDiskSize);
    }

    public long getMaxDiskAge() {
        return maxDiskAge;
    }

    public void setMaxDiskAge(long maxDiskAge) {
        this.maxDiskAge = maxDiskAge;
        native_maxDiskAge(nativeHandle,maxDiskAge);
    }

    public long getLogSize() {
        return native_logSize(nativeHandle);
    }

    public String getDiskCachePath() {
        return native_diskcache_path(nativeHandle);
    }


    private  long nativeHandle;
    private  static  String defaultDiskCacheDirectory(@NonNull Context context){

        return userCacheDirectory(context) + "/com.mxlog.LoggerCache";
    }
    private  static  String userCacheDirectory(@NonNull Context context){

        String cacheDir = context.getFilesDir().getAbsolutePath();
        return  cacheDir;
    }

    private static native long jniInitialize(String nameSpace,String diskCacheDirectory,String storagePolicy,String fileName,String cryptKey,String iv);
    private  static  native  long native_value_for_nameSpace(String nameSpace,String diskCacheDirectory);
    private  static  native void native_log(long nativeHandle,String name,int level,String msg,String tag,boolean mainThread);

    private  static  native  void  native_fileLevel(long nativeHandle,int fileLevel);
    private  static  native  void  native_consoleEnable(long nativeHandle,boolean enable);
    private  static  native  void  native_maxDiskAge(long nativeHandle,long maxDiskAge);
    private  static  native  void  native_maxDiskSize(long nativeHandle,long maxDiskSize);
    private static   native  long  native_logSize(long nativeHandle);
    private  static  native String native_diskcache_path(long nativeHandle);
    private  static  native void native_removeExpireData(long nativeHandle);
    private static  native  void  native_removeAll(long nativeHandle);
}
