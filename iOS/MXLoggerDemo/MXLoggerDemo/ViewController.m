//
//  ViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/3/23.
//

#import "ViewController.h"
#import "MXDemoActionCell.h"
#import "MXDemoHomeViewController.h"
#import "MXDemoL10n.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *subtitleLabel;
@property (weak, nonatomic) IBOutlet UIButton *entryButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.backButtonTitle = @"";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[MXDemoL10n switchButtonTitle]
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(toggleLanguage)];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applyLocalization)
                                                 name:MXDemoLanguageDidChangeNotification
                                               object:nil];
    [self applyLocalization];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    /// 演示主页首屏要一次性建十来个 cell，其中 SF Symbols 目录初始化、cell nib 解档、
    /// Auto Layout/文本渲染的进程级缓存都是一次性成本。这些成本原本压在 push 动画的
    /// 第一帧上，首次点击会明显掉帧，所以挪到入口页出现之后的空闲时机先做掉
    /// The demo home page builds a dozen cells for its first screen, and initializing the
    /// SF Symbols catalog, unarchiving the cell nib and warming the process-wide Auto
    /// Layout / text rendering caches are all one-time costs. They used to land on the
    /// first frame of the push animation and visibly dropped frames on the first tap, so
    /// they are done here instead, once the entry page is idle
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [MXDemoActionCell prewarm];
        });
    });
}

- (void)toggleLanguage {
    [MXDemoL10n toggleLanguage];
}

- (void)applyLocalization {
    self.navigationItem.rightBarButtonItem.title = [MXDemoL10n switchButtonTitle];
    self.subtitleLabel.text = MXDemoStr(@"entry.subtitle");
    [self.entryButton setTitle:MXDemoStr(@"entry.button") forState:UIControlStateNormal];
}

- (IBAction)entryLogButtonAction:(id)sender {
    MXDemoHomeViewController *controller = [[MXDemoHomeViewController alloc] initWithNibName:@"MXDemoHomeViewController" bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
