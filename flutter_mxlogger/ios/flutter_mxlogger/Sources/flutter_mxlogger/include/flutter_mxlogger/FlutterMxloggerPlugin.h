#import <Flutter/Flutter.h>

@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>

/// loggerToken 需要业务层传过来（即 MXLogger.loggerToken，旧名 loggerToken）
/// The business layer passes in the loggerToken (MXLogger.loggerToken, formerly loggerToken)

+(NSInteger) debug:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(NSInteger) info:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(NSInteger) warn:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;


+(NSInteger) error:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

+(NSInteger) fatal:(NSString*) loggerToken name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

@end
