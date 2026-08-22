//
//  MXDemoActionCell.m
//  MXLoggerDemo
//

#import "MXDemoActionCell.h"

NSString * const MXDemoActionCellReuseId = @"MXDemoActionCell";

/// 图标统一用这一个 configuration，缓存键就是 symbol 名字
/// All icons share this one configuration, so the symbol name alone is the cache key
static UIImageSymbolConfiguration *MXDemoIconSymbolConfiguration(void) {
    static UIImageSymbolConfiguration *configuration = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        configuration = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
    });
    return configuration;
}

@interface MXDemoActionCell ()
@property (weak, nonatomic) IBOutlet UIView *iconContainer;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;

/// 复用的开关，第一次用到时才创建
/// The reused switch, created lazily on first use
@property (nonatomic, strong, nullable) UISwitch *switcher;
@end

@implementation MXDemoActionCell

+ (nullable UIImage *)iconImageNamed:(NSString *)systemImageName {
    if (systemImageName.length == 0) return nil;

    static NSMutableDictionary<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });

    UIImage *cached = cache[systemImageName];
    if (cached != nil) return cached;

    UIImageSymbolConfiguration *configuration = MXDemoIconSymbolConfiguration();
    UIImage *image = [UIImage systemImageNamed:systemImageName withConfiguration:configuration]
                     ?: [UIImage systemImageNamed:@"circle.fill" withConfiguration:configuration];
    if (image != nil) {
        cache[systemImageName] = image;
    }
    return image;
}

+ (void)prewarm {
    /// 随便取一个 symbol 就能把 SF Symbols 目录初始化好
    /// Resolving any single symbol is enough to initialize the SF Symbols catalog
    [self iconImageNamed:@"circle.fill"];

    /// nib 解档 + 一次布局，顺带预热 Auto Layout 和文本渲染的进程级缓存
    /// Unarchiving the nib and laying it out once also warms the process-wide Auto Layout
    /// and text rendering caches
    UINib *nib = [UINib nibWithNibName:@"MXDemoActionCell" bundle:nil];
    MXDemoActionCell *prototype = [nib instantiateWithOwner:nil options:nil].firstObject;
    if ([prototype isKindOfClass:MXDemoActionCell.class]) {
        [prototype configureWithIcon:@"circle.fill"
                               tint:UIColor.systemBlueColor
                              title:@"prewarm"
                           subtitle:@"prewarm"
                              value:@"0"];
        prototype.frame = CGRectMake(0, 0, 375, 60);
        [prototype layoutIfNeeded];
    }
}

- (void)configureWithIcon:(NSString *)systemImageName
                     tint:(UIColor *)tint
                    title:(NSString *)title
                 subtitle:(NSString *)subtitle
                    value:(NSString *)value {
    self.iconContainer.backgroundColor = tint;
    self.iconView.image = [MXDemoActionCell iconImageNamed:systemImageName];
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    self.subtitleLabel.hidden = (subtitle.length == 0);
    self.valueLabel.text = value;
    self.valueLabel.hidden = (value.length == 0);

    /// 复位禁用态: cell 复用时上一行可能是不可用的开关行，不复位会把变淡带过来
    /// Reset the disabled look: a reused cell may come from an unavailable switch row,
    /// and without this the dimming would leak into the next row
    self.titleLabel.alpha = 1.0;
    self.iconContainer.alpha = 1.0;
}

- (void)applySwitchAccessoryOn:(BOOL)isOn
                       enabled:(BOOL)enabled
                           tag:(NSInteger)tag
                        target:(id)target
                        action:(SEL)action {
    if (self.switcher == nil) {
        self.switcher = [UISwitch new];
    }
    /// target/action 每次重设，因为 cell 复用后归属的 row 变了
    /// The target/action is reset every time because a reused cell belongs to another row
    [self.switcher removeTarget:nil action:NULL forControlEvents:UIControlEventValueChanged];
    [self.switcher addTarget:target action:action forControlEvents:UIControlEventValueChanged];
    self.switcher.on = isOn;
    self.switcher.enabled = enabled;
    self.switcher.tag = tag;

    /// 不可用时标题和图标一起变淡，让"这个开关在当前构建下没有意义"一眼可见
    /// Dim the title and icon together when unavailable, so "this switch means nothing in
    /// this build" reads at a glance
    CGFloat contentAlpha = enabled ? 1.0 : 0.45;
    self.titleLabel.alpha = contentAlpha;
    self.iconContainer.alpha = contentAlpha;

    if (self.accessoryView != self.switcher) {
        self.accessoryView = self.switcher;
    }
    self.accessoryType = UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)applyAccessoryType:(UITableViewCellAccessoryType)accessoryType {
    if (self.accessoryView != nil) {
        self.accessoryView = nil;
    }
    self.accessoryType = accessoryType;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
}

@end
