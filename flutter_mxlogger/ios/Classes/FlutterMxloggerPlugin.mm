#import "FlutterMxloggerPlugin.h"


@interface FlutterMxloggerPlugin()
{
   
    
}
@end
@implementation FlutterMxloggerPlugin

static MXLogger* _mxlogger;

+(MXLogger*)mxlogger{
    
    return  _mxlogger;
}

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
    
      MXLogger * mxlogger = [[MXLogger alloc] initWithNamespace:nameSpace diskCacheDirectory:directory];
      
      _mxlogger = mxlogger;
      
      result(@{@"nameSpace":nameSpace,@"directory":directory});
      
  } else {
    result(FlutterMethodNotImplemented);
  }
}



@end
