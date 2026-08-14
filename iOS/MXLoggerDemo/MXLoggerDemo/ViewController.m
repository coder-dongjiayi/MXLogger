//
//  ViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/3/23.
//

#import "ViewController.h"
#import "MXDemoHomeViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.backButtonTitle = @"";
}

- (IBAction)entryLogButtonAction:(id)sender {
    MXDemoHomeViewController *controller = [[MXDemoHomeViewController alloc] initWithNibName:@"MXDemoHomeViewController" bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
