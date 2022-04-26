package com.dongjiayi.mxlogger;

import android.content.Context;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleEventObserver;

import androidx.lifecycle.LifecycleOwner;


public class MXLogger implements LifecycleEventObserver {

    @Override
    public void onStateChanged(@NonNull LifecycleOwner source, @NonNull Lifecycle.Event event) {

        if (event == Lifecycle.Event.ON_STOP){


        }
        if (event == Lifecycle.Event.ON_DESTROY){

        }
    }

  private static  String defaultDiskCacheDirectory;


   public  static  MXLogger initWithNamespace(Context context,@NonNull String nameSpace){
       return initWithNamespace(context,nameSpace,null);
   }
    public  static MXLogger initWithNamespace(Context context,@NonNull String nameSpace, @Nullable String directory){


        System.loadLibrary("mxlogger");
        if (directory == null){
          directory = defaultDiskCacheDirectory(context);
      }

        long handle =   jniInitialize(nameSpace,directory);
        if (handle != 0) {
            return new MXLogger(handle);
        }
        throw new IllegalStateException("MXLogger创建失败 [" + nameSpace + "]");
    }

    /**
     * 释放native层内存
     * */
    public  static  void destroy(Context context,@NonNull String nameSpace){
       destroy(context,nameSpace,null);

    }

    public  static void destroy(Context context,@NonNull String nameSpace, @Nullable String directory){


        if (directory == null){
            directory = defaultDiskCacheDirectory(context);
        }
        native_destroy(nameSpace,directory);

    }


    public   void debug(@Nullable String msg){
       debug(null,msg);
    }

    public   void info(@Nullable String msg){
        info(null,msg);
    }

    public   void warn(@Nullable String msg){
        warn(null,msg);
    }
    public   void error(@Nullable String msg){
        error(null,msg);
    }

    public   void fatal(@Nullable String msg){
      fatal(null,msg);
    }


    public   void debug(@Nullable String tag,@Nullable String msg){
        debug(null,tag,msg);
    }

    public   void info(@Nullable String tag,@Nullable String msg){
        info(null,tag,msg);
    }

    public   void warn(@Nullable String tag,@Nullable String msg){
        warn(null,tag,msg);
    }
    public   void error(@Nullable String tag,@Nullable String msg){
        error(null,tag,msg);
    }

    public   void fatal(@Nullable String tag,@Nullable String msg){
        fatal(null,tag,msg);
    }


    public   void debug(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,0,tag,msg);
    }

    public   void info(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,1,tag,msg);
    }

    public   void warn(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,2,tag,msg);
    }
    public   void error(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,3,tag,msg);
    }

    public   void fatal(@Nullable String name, @Nullable String tag,@Nullable String msg){
        log(name,4,tag,msg);
    }

    public   void log(@Nullable String name,@NonNull int level,@Nullable String tag,@Nullable String msg){
        innerLog(0,name,level,msg,tag);
    }


    //删除全部过期文件
    public  void removeExpireData(){
     native_removeExpireData(nativeHandle);
    }
    // 删除全部日志文件
    public  void removeAll(){
       native_removeAll(nativeHandle);
    }

    private static  String defaultDiskCacheDirectory(Context context){
            if (defaultDiskCacheDirectory == null){
                defaultDiskCacheDirectory = userCacheDirectory(context) + "/com.mxlog.LoggerCache";
            }
            return defaultDiskCacheDirectory;
    }
    private static String userCacheDirectory(Context context){
        return context.getFilesDir().getAbsolutePath();
    }

    private void innerLog(int logType,String name,int level,String msg,String tag){

       boolean mainThread = Looper.myLooper() == Looper.getMainLooper();

        native_log(nativeHandle,logType,name,level,msg,tag,mainThread);
    }


    private final long nativeHandle;

    private MXLogger(long handle) {
        nativeHandle = handle;
    }

    private static native String version();
   private  static  native  long jniInitialize(String nameSpace,String directory);
    private  static  native  void native_destroy(String nameSpace,String directory);

   private  static  native  void native_log(long handle,int logType,String name,int level,String msg,String tag,boolean mainThread);

    private  static  native void native_storagePolicy(long handle,String policy);
   private  static  native void native_consolePattern(long handle,String pattern);
   private  static  native void native_filePattern(long handle,String pattern);
   private  static  native void native_consoleLevel(long handle,int level);
   private  static  native void native_fileLevel(long handle,int level);
   private  static  native void native_fileEnable(long handle,boolean enable);
   private  static  native void native_consoleEnable(long handle,boolean enable);
   private  static  native void native_fileName(long handle,String fileName);
   private  static  native void native_fileHeader(long handle,String fileHeader);
   private  static  native void native_maxDiskAge(long handle,long maxDiskAge);
   private  static  native void native_maxDiskSize(long handle,long maxDiskSize);
   private  static  native long native_logSize(long handle);
   private  static  native boolean native_isDebugTracking(long handle);
   private  static native  void native_removeExpireData(long handle);
   private  static native  void native_removeAll(long handle);
}
