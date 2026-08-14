//
//  MXLogFileCell.h
//  MXLoggerDemo
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const MXLogFileCellReuseId;

@interface MXLogFileCell : UITableViewCell

- (void)configureWithName:(NSString *)name dates:(NSString *)dates size:(NSString *)size;

@end

NS_ASSUME_NONNULL_END
