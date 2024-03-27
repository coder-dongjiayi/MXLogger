package com.dongjiayi.mxlogger;


import android.content.Context;
import android.os.Looper;
import android.provider.Settings;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
enum MXStoragePolicyType{
    /** 按天存储 对应文件名: 2023-01-11_filename.mx*/
    YYYY_MM_DD,
    /** 按小时存储 对应文件名: 2023-01-11-15_filename.mx*/
    YYYY_MM_DD_HH,
    /**  按周存储 对应文件名: 2023-01-02w_filename.mx（02w是指一年中的第2周）*/
    YYYY_WW,
    /** 按月存储 对应文件名: 2023-01_filename.mx*/
    YYYY_MM
}

public class MXLogger {

    static {
        System.loadLibrary("mxlogger");
    }
    /**
  * 是否开启控制台打印，默认不开启, 开始控制台打印会影响 写入效率 ，建议发布模式禁用 consoleEnable
  * */
  private boolean consoleEnable;

    /**
  * 禁用日志 默认false;
  * */
  private boolean enable;

    /**
   * 日志文件最大字节数 默认0 无限制
   * */
    private long maxDiskSize;

  /**
   * 日志文件最大存储时长 默认0 无限制
   * */
  private  long maxDiskAge;
    /**
   * 设置写入文件日志等级 低于这个等级的日志不会被写入到文件，只可能被输出到控制台
   * */
    private int level;

    /**
     * 获取磁盘缓存目录
     * */
  private String diskCachePath;
    /**
   * 获取当前日志文件大小
   * */
    private  long logSize;

    /**
   *   nameSpace+diskCacheDirectory 做一次md5的值，对应一个logger对象，可以通过这个操作logger对象
     *  业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)
     * 但是你希望所有子模块(子组件)使用在主工程初始化的log，
     *  这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey 进行日志写入
   * */
  private  String loggerKey;

 /**
  * nameSpace 日志命名空间 建议使用域名反转保证唯一性
  * diskCacheDirectory 日志初始化目录
  * storagePolicy 文件存储策略
  * fileName 自定义文件名 默认为:log
  * fileHeader   日志文件头信息，业务可以在初始化mxlogger的时候 写入一些业务相关的信息 比如app版本 所属平台等等 文件创建的时候这条数据会被写入
  * cryptKey aesCFB128 秘钥
  * iv aesCFB128 iv
  *
  * */
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

    /// 删除过期文件
   public void  removeExpireData(){
       native_removeExpireData(nativeHandle);
   }
   /// 删除除当前正在写入的所有日志文件
   public  void removeBeforeAllData(){
       native_removeBeforeAll(nativeHandle);
   }
   /// 删除所有日志文件
  public  void  removeAll(){
      native_removeAll(nativeHandle);
  }
    public  int debug(@Nullable String tag, @Nullable String name, @Nullable String msg){
        return log(tag,0,name,msg);
    }
    public  int info(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,1,name,msg);
    }
    public  int warn(@Nullable String tag,@Nullable String name,@Nullable String msg){
        return log(tag,2,name,msg);
    }
    public  int error(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,3,name,msg);
    }
    public  int fatal(@Nullable String tag,@Nullable String name,@Nullable String msg){
       return log(tag,4,name,msg);
    }
    /**
     * tag 标记
     * level 0_debug 1_info 2_warn 3_error 4_fatal
     * name name
     * msg 日志信息
    * */
    public  int log(@Nullable String tag,@Nullable int level,@Nullable String name,@Nullable String msg){

       return innerLog(tag,level,msg,name);
    }
    private  int innerLog(@Nullable String tag,@Nullable int level,@Nullable String msg,@Nullable String name){
        if(enable) return 0;
       boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
       return native_log(nativeHandle,name,level,msg,tag,isMainThread);
    }

    public MXLogger(@NonNull Context context,@NonNull String nameSpace,@Nullable String fileHeader) {

        this(context,nameSpace,null,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,null,null);
    }

    public MXLogger(@NonNull Context context,
                    @NonNull String nameSpace,
                    @Nullable String fileHeader,
                    @Nullable String cryptKey,
                    @Nullable String iv) {
        this(context,nameSpace,null,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,cryptKey,iv);
    }

    public MXLogger(@NonNull Context context,
                    @Nullable String fileHeader,
                    @NonNull String nameSpace,
                    @Nullable String diskCacheDirectory) {
        this(context,nameSpace,diskCacheDirectory,MXStoragePolicyType.YYYY_MM_DD,null,fileHeader,null,null);

    }

    public void setConsoleEnable(boolean consoleEnable) {
        this.consoleEnable = consoleEnable;
        native_consoleEnable(nativeHandle,consoleEnable);
    }

    public boolean isConsoleEnable() {
        return consoleEnable;
    }


    public int getLevel() {
        return level;
    }

    public void setLevel(int level) {
        this.level = level;
        native_level(nativeHandle,level);
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


    /**
     * 获取错误信息
     * */
    public  String getErrorDesc(){return  native_errorDesc(nativeHandle);}

    private final long nativeHandle;
    private  static  String defaultDiskCacheDirectory(@NonNull Context context){

        return userCacheDirectory(context) + "/com.mxlog.LoggerCache";
    }
    private  static  String userCacheDirectory(@NonNull Context context){

        String cacheDir = context.getFilesDir().getAbsolutePath();
        return  cacheDir;
    }

    /**
     *  销毁C++对象
     * */
    public static void  destroy(@NonNull Context context, @NonNull String nameSpace,
                                @Nullable String diskCacheDirectory){
        if(diskCacheDirectory == null){
            diskCacheDirectory = defaultDiskCacheDirectory(context);
        }
        native_destroy(nameSpace,diskCacheDirectory);
    }

    /**
     *  通过loggerKey 销毁C++对象
     * */
    public static void  destroy(@NonNull String loggerKey){
        native_destroy_loggerKey(loggerKey);
    }
    public String getLoggerKey() {
        return native_loggerKey(nativeHandle);
    }

    /**
     * 根据mapKey 获取已初始化的logger对象 然后进行日志写入操作
     * 如果没有获取到logger对象 则没有调用这个方法没有任何反应 也不会报错
     * */
    public static int log(@NonNull String loggerKey, @Nullable String tag,@NonNull int level,@Nullable String name,@Nullable String msg){
        boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
       return native_log_loggerKey(loggerKey,name,level,msg,tag,isMainThread);
    }

    private static native long jniInitialize(String nameSpace,String diskCacheDirectory,String storagePolicy,String fileName, String fileHeader, String cryptKey,String iv);

    private  static  native int native_log(long nativeHandle,String name,int level,String msg,String tag,boolean mainThread);
    private  static  native int native_log_loggerKey(String loggerKey,String name,int level,String msg,String tag,boolean mainThread);

    private  static  native  void  native_level(long nativeHandle,int level);
    private  static  native  void  native_consoleEnable(long nativeHandle,boolean enable);
    private  static  native  void  native_maxDiskAge(long nativeHandle,long maxDiskAge);
    private  static  native  void  native_maxDiskSize(long nativeHandle,long maxDiskSize);
    private static   native  long  native_logSize(long nativeHandle);
    private  static  native String native_diskcache_path(long nativeHandle);
    private  static  native  String native_errorDesc(long nativeHandle);
    private  static  native void native_removeExpireData(long nativeHandle);
    private static  native  void  native_removeAll(long nativeHandle);
    private static  native  void  native_removeBeforeAll(long nativeHandle);
    private static native  String native_loggerKey(long nativeHandle);
    private  static native  void native_destroy(String nameSpace,String diskCacheDirectory);
    private static native void native_destroy_loggerKey(String loggerKey);

}
