package com.bling.mxlogger;

import android.content.Context;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

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
      String directory = "";
       if (call.argument("directory") == null){
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


  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }
}
