#import <Flutter/Flutter.h>

@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>

/// mapKey 需要业务层传过来

+(void) debug:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(void) info:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(void) warn:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(void) error:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(void) fatal:(NSString*) mapKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

@end
