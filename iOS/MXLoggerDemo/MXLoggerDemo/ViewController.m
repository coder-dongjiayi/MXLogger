//
//  ViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/3/23.
//

#import "ViewController.h"

#import <MXLogger/MXLogger.h>
#import "LogViewController.h"

@interface ViewController ()
{
   MXLogger * _logger;
    NSString * _cryptKey;
    NSString * _iv;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];


}


- (IBAction)entryLogButtonAction:(id)sender {
    LogViewController * controller = [[LogViewController alloc] initWithNibName:nil bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
}







@end
