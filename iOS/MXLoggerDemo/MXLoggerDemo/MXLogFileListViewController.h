//
//  MXLogFileListViewController.h
//  MXLoggerDemo
//
//  日志文件列表: 演示 logFiles API
//

#import <UIKit/UIKit.h>

@class MXLogger;

NS_ASSUME_NONNULL_BEGIN

@interface MXLogFileListViewController : UIViewController

@property (nonatomic, strong) MXLogger *logger;
@property (nonatomic, copy) NSString *cryptKey;
@property (nonatomic, copy) NSString *iv;

@end

NS_ASSUME_NONNULL_END
