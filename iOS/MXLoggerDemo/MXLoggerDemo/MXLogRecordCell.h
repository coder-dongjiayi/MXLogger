//
//  MXLogRecordCell.h
//  MXLoggerDemo
//
//  单条日志: 等级徽章 + 时间 + 内容 + tag/线程信息
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MXLogRecordCellReuseId;

@interface MXLogRecordCell : UITableViewCell

- (void)configureWithRecord:(NSDictionary *)record;

@end

NS_ASSUME_NONNULL_END
