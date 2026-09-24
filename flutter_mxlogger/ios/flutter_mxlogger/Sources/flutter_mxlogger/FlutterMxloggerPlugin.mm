#import "./include/flutter_mxlogger/FlutterMxloggerPlugin.h"
#import <MXLogger/MXLogger.h>
/// 定义在 flutter-bridge.mm，见该文件末尾的说明 / Defined in flutter-bridge.mm, see the note at its end
extern "C" void flutter_mxlogger_ffi_anchor(void);

@interface FlutterMxloggerPlugin()
{
   
    
}
@end
@implementation FlutterMxloggerPlugin


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  // 引用一次 FFI 桥接文件的符号，防止静态链接(SwiftPM)时整个 .o 被链接器丢弃
  // Touch the FFI bridge once so the linker keeps its object file under static linking (SwiftPM)
  flutter_mxlogger_ffi_anchor();
 
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
    
      result(@{@"nameSpace":nameSpace,@"directory":directory});
      
  } else {
    result(FlutterMethodNotImplemented);
  }
}

+(NSInteger) debug:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerToken] == YES) return 0;
    
    return  [self log:loggerToken level:0 name:name msg:msg tag:tag];
   
}

+(NSInteger) info:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerToken] == YES) return 0;
    
    return  [self log:loggerToken level:1 name:name msg:msg tag:tag];
   
}

+(NSInteger) warn:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerToken] == YES) return 0;
    
   return [self log:loggerToken level:2 name:name msg:msg tag:tag];
   
}

+(NSInteger) error:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerToken] == YES) return 0;
    
    return [self log:loggerToken level:3 name:name msg:msg tag:tag];
   
}
+(NSInteger) fatal:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerToken] == YES) return 0;
    
   return [self log:loggerToken level:4 name:name msg:msg tag:tag];
   
}

+(NSInteger)log:(NSString*)loggerToken level:(NSInteger) level name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
   
    MXLogger * logger =  [MXLogger valueForLoggerToken:loggerToken];
    
    return  [logger logWithLevel:level name:name msg:msg tag:tag];
}

+(BOOL)isNull:(NSString*) object{
    if (object == NULL || object == nullptr) {
        return YES;
    }
    if ([object isKindOfClass:[NSNull class]]) {
        return YES;
    }
    return NO;
}

@end
