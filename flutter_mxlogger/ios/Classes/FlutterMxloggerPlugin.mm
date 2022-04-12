#import "FlutterMxloggerPlugin.h"

#include "mxlogger_manager.hpp"

@implementation FlutterMxloggerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"flutter_mxlogger"
            binaryMessenger:[registrar messenger]];
  FlutterMxloggerPlugin* instance = [[FlutterMxloggerPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    
  if ([@"initialize" isEqualToString:call.method]) {
      NSDictionary * arguments = (NSDictionary*)call.arguments;
      NSString * nameSpace = arguments[@"nameSpace"];
      NSString * directory = @"";

      if ([arguments[@"directory"] isKindOfClass:[NSNull class]]) {
          NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
          directory =  [libraryPath stringByAppendingPathComponent:@"com.mxlog.LoggerCache"];
          
      }else{
          directory = arguments[@"directory"];
      }
     NSString * diskCachePath  = [[directory stringByAppendingPathComponent:nameSpace] stringByAppendingString:@"/"];
      mx_logger::instance().set_file_dir([diskCachePath UTF8String]);
      result(@YES);
      
  } else {
    result(FlutterMethodNotImplemented);
  }
}

@end
