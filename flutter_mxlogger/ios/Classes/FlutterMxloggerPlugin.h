#import <Flutter/Flutter.h>

@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>

/// loggerKey 需要业务层传过来

+(NSInteger) debug:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(NSInteger) info:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(NSInteger) warn:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(NSInteger) error:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(NSInteger) fatal:(NSString*) loggerKey name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

@end
