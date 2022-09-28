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

+(void) debug:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:mapKey] == YES) return;
    
    [self log:mapKey level:0 name:name msg:msg tag:tag];
   
}

+(void) info:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:mapKey] == YES) return;
    
    [self log:mapKey level:1 name:name msg:msg tag:tag];
   
}

+(void) warn:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:mapKey] == YES) return;
    
    [self log:mapKey level:2 name:name msg:msg tag:tag];
   
}

+(void) error:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:mapKey] == YES) return;
    
    [self log:mapKey level:3 name:name msg:msg tag:tag];
   
}
+(void) fatal:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
    if([self isNull:mapKey] == YES) return;
    
    [self log:mapKey level:4 name:name msg:msg tag:tag];
   
}

+(void)log:(NSString*)mapKey level:(NSInteger) level name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag{
   
    MXLogger * logger =  [MXLogger valueForMapKey:mapKey];
    
    [logger log:level name:name msg:msg tag:tag];
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
