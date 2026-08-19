//
//  ViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/3/23.
//

#import "ViewController.h"
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
