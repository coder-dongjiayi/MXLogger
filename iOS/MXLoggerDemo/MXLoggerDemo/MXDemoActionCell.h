//
//  MXDemoActionCell.h
//  MXLoggerDemo
//
//  演示主页功能行: 彩色圆角图标 + 标题/副标题 + 右侧值
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MXDemoActionCellReuseId;

@interface MXDemoActionCell : UITableViewCell

- (void)configureWithIcon:(NSString *)systemImageName
                     tint:(UIColor *)tint
                    title:(NSString *)title
                 subtitle:(nullable NSString *)subtitle
                    value:(nullable NSString *)value;

@end

NS_ASSUME_NONNULL_END
