package com.dongjiayi.mxlogger;


import android.content.Context;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

public class MXLogger {


    private  long nativeHandle;
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


    public  void log(@Nullable String tag,@Nullable int level,@Nullable String name,@Nullable String msg){

        innerLog(tag,level,msg,name);
    }
    private  void innerLog(@Nullable String tag,@Nullable int level,@Nullable String msg,@Nullable String name){
       boolean isMainThread = Looper.myLooper() == Looper.getMainLooper();
        native_log(nativeHandle,name,level,msg,tag,isMainThread);
    }
    private  static  String defaultDiskCacheDirectory(@NonNull Context context){

        return userCacheDirectory(context) + "/com.mxlog.LoggerCache";
    }
    private  static  String userCacheDirectory(@NonNull Context context){
        String cacheDir = context.getCacheDir().getAbsolutePath();
        return  cacheDir;
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

    private static native long jniInitialize(String nameSpace,String diskCacheDirectory,String storagePolicy,String fileName,String cryptKey,String iv);

    private  static  native void native_log(long handle,String name,int level,String msg,String tag,boolean mainThread);

}
