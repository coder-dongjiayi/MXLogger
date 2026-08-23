//
//  MXLogFileCell.m
//  MXLoggerDemo
//

#import "MXLogFileCell.h"

NSString * const MXLogFileCellReuseId = @"MXLogFileCell";

@interface MXLogFileCell ()
@property (weak, nonatomic) IBOutlet UIView *iconContainer;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@end

@implementation MXLogFileCell

- (void)awakeFromNib {
    [super awakeFromNib];
    self.iconView.image = [UIImage systemImageNamed:@"doc.text.fill"];
    self.iconView.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightMedium];
}

- (void)configureWithName:(NSString *)name dates:(NSString *)dates size:(NSString *)size {
    self.nameLabel.text = name;
    self.dateLabel.text = dates;
    self.sizeLabel.text = size;
}

@end
