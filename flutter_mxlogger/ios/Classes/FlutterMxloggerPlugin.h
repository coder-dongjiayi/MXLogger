#import <Flutter/Flutter.h>
#import <MXLogger/MXLogger.h>
@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>
+(MXLogger*)logger;
@end
