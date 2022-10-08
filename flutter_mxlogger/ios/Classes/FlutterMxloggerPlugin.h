#import <Flutter/Flutter.h>

@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>

/// loggerKey 需要业务层传过来

+(void) debug:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(void) info:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(void) warn:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(void) error:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(void) fatal:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

@end
