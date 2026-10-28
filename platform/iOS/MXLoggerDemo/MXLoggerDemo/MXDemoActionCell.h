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

/// 开关行: UISwitch 由 cell 持有复用，只切状态，不每次 new。
/// enabled 为 NO 时开关不可点，标题与图标一并变淡，用于表示"当前构建下该能力不可用"
/// Switch row: the cell owns and reuses the UISwitch, only its state is updated.
/// When enabled is NO the switch is not interactive and the title/icon dim along with it,
/// marking the capability as unavailable in this build
- (void)applySwitchAccessoryOn:(BOOL)isOn
                       enabled:(BOOL)enabled
                           tag:(NSInteger)tag
                        target:(id)target
                        action:(SEL)action;

/// 非开关行: 还原 accessory
/// Non-switch row: restore the accessory
- (void)applyAccessoryType:(UITableViewCellAccessoryType)accessoryType;

/// 按 name 取带 symbol configuration 的图标，进程内缓存。
/// 首次 [UIImage systemImageNamed:] 要初始化整个 SF Symbols 目录(实测冷启动 9~19ms)，
/// 之后每个新 symbol 仍有 0.5~6ms，滚动复用时每次现算会一直付这笔钱
/// Fetches the icon for a name with the symbol configuration applied, cached per process.
/// The first [UIImage systemImageNamed:] has to spin up the whole SF Symbols catalog
/// (measured at 9-19ms cold) and every new symbol still costs 0.5-6ms after that, so
/// resolving it on each reuse keeps paying that price
+ (nullable UIImage *)iconImageNamed:(NSString *)systemImageName;

/// 预热 SF Symbols 目录和 cell 的 nib，把首次成本从页面 push 路径里挪走
/// Warms up the SF Symbols catalog and the cell nib, moving the first-time cost off the
/// page push path
+ (void)prewarm;

@end

NS_ASSUME_NONNULL_END
