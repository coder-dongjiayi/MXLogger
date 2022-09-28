#import <Flutter/Flutter.h>
#import <MXLogger/MXLogger.h>
@interface FlutterMxloggerPlugin : NSObject<FlutterPlugin>
/// 调用这个方法有效的前提 是已经在主工程中 使用 Future<MXLogger> initialize() 方法初始化完毕，否则这将返回null
+(MXLogger*)mxlogger;
@end
