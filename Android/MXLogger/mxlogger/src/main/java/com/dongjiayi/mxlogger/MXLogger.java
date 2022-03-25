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

    private static native String version();
   /**
   * 初始化日志文件目录
   */
   private  static  native  void jniInitialize(String diskCachePath);

   private  static  native  void log(int logType,String name,int level,String msg,String tag,boolean mainThread);

   private  static  native void native_storagePolicy(String policy);
}
