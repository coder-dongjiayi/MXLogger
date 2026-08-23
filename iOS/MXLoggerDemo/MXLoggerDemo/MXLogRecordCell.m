//
//  MXLogRecordCell.m
//  MXLoggerDemo
//

#import "MXLogRecordCell.h"
#import "MXDemoL10n.h"

NSString * const MXLogRecordCellReuseId = @"MXLogRecordCell";

@interface MXLogRecordCell ()
@property (weak, nonatomic) IBOutlet UIView *badgeContainer;
@property (weak, nonatomic) IBOutlet UILabel *badgeLabel;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *msgLabel;
@property (weak, nonatomic) IBOutlet UIView *tagContainer;
@property (weak, nonatomic) IBOutlet UILabel *tagLabel;
@property (weak, nonatomic) IBOutlet UILabel *threadLabel;
@end

@implementation MXLogRecordCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
}

- (void)configureWithRecord:(NSDictionary *)record {
    NSInteger level = [record[@"level"] integerValue];
    BOOL parseFailed = [record[@"error_code"] integerValue] != 0;

    static NSArray *names = nil;
    static NSArray *colors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @[@"DEBUG", @"INFO", @"WARN", @"ERROR", @"FATAL"];
        colors = @[UIColor.systemGrayColor, UIColor.systemBlueColor, UIColor.systemOrangeColor,
                   UIColor.systemRedColor, UIColor.systemPurpleColor];
    });

    if (parseFailed) {
        self.badgeLabel.text = @"BAD";
        self.badgeContainer.backgroundColor = UIColor.systemRedColor;
    } else if (level >= 0 && level < (NSInteger)names.count) {
        self.badgeLabel.text = names[level];
        self.badgeContainer.backgroundColor = colors[level];
    } else {
        self.badgeLabel.text = @"?";
        self.badgeContainer.backgroundColor = UIColor.systemGrayColor;
    }

    NSString *name = [record[@"name"] description];
    self.nameLabel.text = name.length > 0 ? name : @"-";
    self.timeLabel.text = [self timeText:record[@"timestamp"]];
    self.msgLabel.text = parseFailed
        ? [NSString stringWithFormat:MXDemoStr(@"record.parse.failed.fmt"), record[@"msg"] ?: @""]
        : [record[@"msg"] description];

    NSString *tag = [record[@"tag"] description];
    BOOL hasTag = tag.length > 0;
    self.tagContainer.hidden = !hasTag;
    self.tagLabel.text = hasTag ? [NSString stringWithFormat:@"# %@", tag] : nil;

    BOOL isMain = [record[@"is_main_thread"] boolValue];
    self.threadLabel.text = [NSString stringWithFormat:@"%@ · tid %@",
                             MXDemoStr(isMain ? @"record.thread.main" : @"record.thread.sub"),
                             record[@"thread_id"] ?: @"-"];
}

- (NSString *)timeText:(id)timestamp {
    // 日志记录的 timestamp 是微秒(core 用 time_stamp_microseconds 写入)，按量级识别兼容秒/毫秒
    NSTimeInterval interval = [[timestamp description] doubleValue];
    if (interval <= 0) return [timestamp description] ?: @"-";
    if (interval > 1e14) interval /= 1e6;       // 微秒
    else if (interval > 1e11) interval /= 1e3;  // 毫秒
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
        formatter.dateFormat = @"MM-dd HH:mm:ss.SSS";
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:interval]];
}

@end
