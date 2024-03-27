#import "FlutterMxloggerPlugin.h"
#import <MXLogger/MXLogger.h>
@interface FlutterMxloggerPlugin()
{
   
    
}
@end
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
    
      result(@{@"nameSpace":nameSpace,@"directory":directory});
      
  } else {
    result(FlutterMethodNotImplemented);
  }
}

+(NSInteger) debug:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerKey] == YES) return 0;
    
    return  [self log:loggerKey level:0 name:name msg:msg tag:tag];
   
}

+(NSInteger) info:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerKey] == YES) return 0;
    
    return  [self log:loggerKey level:1 name:name msg:msg tag:tag];
   
}

+(NSInteger) warn:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerKey] == YES) return 0;
    
   return [self log:loggerKey level:2 name:name msg:msg tag:tag];
   
}

+(NSInteger) error:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerKey] == YES) return 0;
    
    return [self log:loggerKey level:3 name:name msg:msg tag:tag];
   
}
+(NSInteger) fatal:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:loggerKey] == YES) return 0;
    
   return [self log:loggerKey level:4 name:name msg:msg tag:tag];
   
}

+(NSInteger)log:(NSString*)loggerKey level:(NSInteger) level name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
   
    MXLogger * logger =  [MXLogger valueForLoggerKey:loggerKey];
    
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
