//
//  MXDemoActionCell.m
//  MXLoggerDemo
//

#import "MXDemoActionCell.h"

NSString * const MXDemoActionCellReuseId = @"MXDemoActionCell";

@interface MXDemoActionCell ()
@property (weak, nonatomic) IBOutlet UIView *iconContainer;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UILabel *valueLabel;
@end

@implementation MXDemoActionCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightSemibold];
}

- (void)configureWithIcon:(NSString *)systemImageName
                     tint:(UIColor *)tint
                    title:(NSString *)title
                 subtitle:(NSString *)subtitle
                    value:(NSString *)value {
    self.iconContainer.backgroundColor = tint;
    self.iconView.image = [UIImage systemImageNamed:systemImageName] ?: [UIImage systemImageNamed:@"circle.fill"];
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    self.subtitleLabel.hidden = (subtitle.length == 0);
    self.valueLabel.text = value;
    self.valueLabel.hidden = (value.length == 0);
}

@end
