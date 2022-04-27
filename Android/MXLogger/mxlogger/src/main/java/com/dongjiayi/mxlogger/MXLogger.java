package com.dongjiayi.mxlogger;

import android.content.Context;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleEventObserver;

import androidx.lifecycle.LifecycleOwner;

import java.security.Principal;


public class MXLogger  {



    private static  String defaultDiskCacheDirectory;


    ///  文件存储策略
///  yyyy_MM                    按月存储
///  yyyy_MM_dd              按天存储
///  yyyy_ww                     按周存储
///  yyyy_MM_dd_HH       按小时存储
    private String storagePolicy;
    /// 控制台输出样式
    private String consolePattern;
    /// 写入文件输出样式
    private String filePattern;
    /// 设置控制台日志输出等级
    private int consoleLevel;
    /// 设置写入文件日志等级
    private int fileLevel;

    /// 禁用/开启 文件写入
    private boolean fileEnable;

    /// 禁用/开启 控制台输出 默认情况下
    // 如果进程处于被调试状态(isDebugTracking = YES) 那么就会在控制台输出日志信息，
    // 如果处于非调试状态(isDebugTracking = NO)下则只会写入文件不会输出到控制台

    private boolean consoleEnable;
    /// 禁用日志
    private boolean enable;
    /// 自定义日志文件名 默认值:mxlog
    private String fileName;
    /// 每次创建一个新的日志文件 写入文件头的信息
    private String fileHeader;
    /// 日志文件存储最长时间 默认0 无限制
    private int maxDiskAge;

    /// 日志文件最大字节数 默认0 无限制
    private long maxDiskSize;

    /// 当前进程是否正在被调试
    private boolean isDebugTracking;

    /// 日志文件大小
    private long logSize;

    public long getLogSize() {
        return native_logSize(nativeHandle);
    }


    public String getDiskCachePath() {
        return native_diskcache_path(nativeHandle);
    }


    private String diskCachePath;

    public String getStoragePolicy() {
        return storagePolicy;
    }

    public void setStoragePolicy(String storagePolicy) {
        this.storagePolicy = storagePolicy;
        native_storagePolicy(nativeHandle,storagePolicy);
    }

    public String getConsolePattern() {
        return consolePattern;
    }

    public void setConsolePattern(String consolePattern) {
        this.consolePattern = consolePattern;
        native_consolePattern(nativeHandle,consolePattern);
    }

    public String getFilePattern() {
        return filePattern;
    }

    public void setFilePattern(String filePattern) {
        this.filePattern = filePattern;
        native_filePattern(nativeHandle,filePattern);
    }

    public int getConsoleLevel() {
        return consoleLevel;
    }

    public void setConsoleLevel(int consoleLevel) {
        this.consoleLevel = consoleLevel;
        native_consoleLevel(nativeHandle,consoleLevel);
    }

    public int getFileLevel() {
        return fileLevel;
    }

    public void setFileLevel(int fileLevel) {
        this.fileLevel = fileLevel;
        native_fileLevel(nativeHandle,fileLevel);
    }

    public boolean isFileEnable() {
        return fileEnable;
    }

    public void setFileEnable(boolean fileEnable) {
        this.fileEnable = fileEnable;
        native_fileEnable(nativeHandle,fileEnable);
    }

    public boolean isConsoleEnable() {
        return consoleEnable;
    }

    public void setConsoleEnable(boolean consoleEnable) {
        this.consoleEnable = consoleEnable;
        native_consoleEnable(nativeHandle,consoleEnable);
    }

    public boolean isEnable() {
        return enable;
    }

    public void setEnable(boolean enable) {
        this.enable = enable;
        native_enable(nativeHandle,enable);
    }

    public String getFileName() {
        return fileName;
    }

    public void setFileName(String fileName) {
        this.fileName = fileName;
        native_fileName(nativeHandle,fileName);
    }

    public String getFileHeader() {
        return fileHeader;
    }

    public void setFileHeader(String fileHeader) {
        this.fileHeader = fileHeader;
        native_fileHeader(nativeHandle,fileHeader);
    }

    public int getMaxDiskAge() {
        return maxDiskAge;
    }

    public void setMaxDiskAge(int maxDiskAge) {
        this.maxDiskAge = maxDiskAge;
        native_maxDiskAge(nativeHandle,maxDiskAge);
    }

    public long getMaxDiskSize() {
        return maxDiskSize;
    }

    public void setMaxDiskSize(long maxDiskSize) {
        this.maxDiskSize = maxDiskSize;
        native_maxDiskSize(nativeHandle,maxDiskSize);
    }

    public boolean isDebugTracking() {
        return native_isDebugTracking(nativeHandle);
    }




   public  static  MXLogger initWithNamespace(Context context, @NonNull String nameSpace){
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

    @NonNull
    private static String userCacheDirectory(@NonNull Context context){
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


   private  static  native  long jniInitialize(String nameSpace,String directory);
    private  static  native  void native_destroy(String nameSpace,String directory);

   private  static  native  void native_log(long handle,int logType,String name,int level,String msg,String tag,boolean mainThread);

    private  static  native void native_storagePolicy(long handle,String policy);

   private  static  native void native_consolePattern(long handle,String pattern);
   private  static  native void native_filePattern(long handle,String pattern);
   private  static  native void native_consoleLevel(long handle,int level);
   private  static  native void native_fileLevel(long handle,int level);
   private  static  native void native_fileEnable(long handle,boolean enable);
   private static native  void native_enable(long handle,boolean enable);
   private  static  native void native_consoleEnable(long handle,boolean enable);
   private  static  native void native_fileName(long handle,String fileName);
   private  static  native void native_fileHeader(long handle,String fileHeader);
   private  static  native void native_maxDiskAge(long handle,long maxDiskAge);
   private  static  native void native_maxDiskSize(long handle,long maxDiskSize);
   private  static  native long native_logSize(long handle);
   private  static  native boolean native_isDebugTracking(long handle);
   private  static native  void native_removeExpireData(long handle);
   private  static native  void native_removeAll(long handle);
   private  static native  String native_diskcache_path(long handle);
}
