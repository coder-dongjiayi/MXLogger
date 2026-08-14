//
//  MXLogViewerViewController.h
//  MXLoggerDemo
//
//  日志查看器: 演示 selectWithDiskCacheFilePath:cryptKey:iv: 解析日志文件
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MXLogViewerViewController : UIViewController

@property (nonatomic, copy) NSString *filePath;   // 日志文件完整路径
@property (nonatomic, copy, nullable) NSString *fileName;
@property (nonatomic, copy, nullable) NSString *cryptKey;
@property (nonatomic, copy, nullable) NSString *iv;

@end

NS_ASSUME_NONNULL_END
