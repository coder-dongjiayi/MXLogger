package com.coderdjy.mxlogger;

import android.content.Context;


import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.dongjiayi.mxlogger.MXLogger;

import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;


/** FlutterMxloggerPlugin */
public class FlutterMxloggerPlugin implements FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;

  private Context _context;
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {

    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_mxlogger");
    channel.setMethodCallHandler(this);

    _context = flutterPluginBinding.getApplicationContext();
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("initialize")) {
      final String nameSpace = call.argument("nameSpace");
      String directory = call.argument("directory");
       if (directory == null){
         directory = _context.getFilesDir().getAbsolutePath() + "/com.mxlog.LoggerCache";
       }
      HashMap<String,String> map = new HashMap<>();
       map.put("nameSpace",nameSpace);
      map.put("directory",directory);

      result.success(map);
    } else {
      result.notImplemented();
    }
  }

  public static  void debug(@NonNull String loggerKey, @Nullable String tag,@Nullable String name,@Nullable String msg){
    log(loggerKey,tag,0,name,msg);
  }

  public static  void info(@NonNull String loggerKey, @Nullable String tag,@Nullable String name,@Nullable String msg){
    log(loggerKey,tag,1,name,msg);
  }
  public static  void warn(@NonNull String loggerKey, @Nullable String tag,@Nullable String name,@Nullable String msg){
    log(loggerKey,tag,2,name,msg);
  }
  public static  void error(@NonNull String loggerKey, @Nullable String tag,@Nullable String name,@Nullable String msg){
    log(loggerKey,tag,3,name,msg);
  }
  public static  void fatal(@NonNull String loggerKey, @Nullable String tag,@Nullable String name,@Nullable String msg){
    log(loggerKey,tag,4,name,msg);
  }

  private static void log(@NonNull String loggerKey, @Nullable String tag,@NonNull int level,@Nullable String name,@Nullable String msg){
    MXLogger.log(loggerKey,tag,level,name,msg);
  }
  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
