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



- (IBAction)removeAllButtonAction:(id)sender {
   
    [_logger removeAllData];
}



- (IBAction)readLogButtonAction:(id)sender {

    NSArray * array =   [MXLogger selectLogfilesWithDirectory:_logger.diskCachePath];

    NSString * path = [NSString stringWithFormat:@"%@%@",_logger.diskCachePath,array.firstObject[@"name"]];

   NSArray * result =  [MXLogger selectWithDiskCacheFilePath:path cryptKey:_cryptKey iv:_iv];

    [result enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * msg = obj[@"msg"];
        NSString * tm = obj[@"timestamp"];
        NSString * tag = obj[@"tag"];
        NSString * name = obj[@"name"];
        NSString * level = obj[@"level"];
        NSString *  is_main = obj[@"is_main_thread"];
        NSString * threadId = obj[@"thread_id"];
        NSLog(@"\n[%@] tm:%@,msg:%@,tag:%@,level:%@ thread_id=%@ is_main=%@",name,tm,msg,tag,level,threadId,is_main);
    }];
}




@end
