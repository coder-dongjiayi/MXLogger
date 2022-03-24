package com.dongjiayi.mxlogger;

import android.content.Context;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class MXLogger {
    private static  String defaultDiskCacheDirectory;

    public static   @NonNull String diskCachePath;

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
    public static native String version();
   /**
   * 初始化日志文件目录
   */
    public  static  native  void jniInitialize(String diskCachePath);
}
