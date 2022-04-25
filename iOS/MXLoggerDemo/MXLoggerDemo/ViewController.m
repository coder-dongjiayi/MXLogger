//
//  ViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/3/23.
//

#import "ViewController.h"
#import <MXLogger/MXLogger.h>
@interface ViewController ()
{
   MXLogger * _logger;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _logger =   [MXLogger initializeWithNamespace:@"default"];
    
    NSString * isDebug = _logger.isDebugTracking == YES ? @"正在调试" : @"非调试状态";
        _logger.fileHeader =  [NSString stringWithFormat:@"版本号:1.0.0 平台:iOS isDebug:%@",isDebug];

    [_logger info:@"mxlogger" msg:[NSString stringWithFormat:@"%@",isDebug] tag:@"isDebug"];
    [_logger info:@"mxlogger" msg:_logger.diskCachePath tag:@"日志目录"];

    _logger.maxDiskAge = 60 * 60 * 24 * 7; // 一个星期
    _logger.maxDiskSize = 1024 * 1024 * 10; // 10M
    
    //    /**下面这些设置都是默认设置 不写也行 **/
   

    _logger.storagePolicy = @"yyyy_MM_dd";
    _logger.fileName = @"mxlog";

    _logger.shouldRemoveExpiredDataWhenEnterBackground = YES;

    _logger.shouldRemoveExpiredDataWhenTerminate = YES;

    _logger.consoleLevel = 0;
    _logger.fileLevel = 1;

    _logger.consolePattern = @"[%d][%p]%m";
    _logger.filePattern = @"[%d][%t][%p]%m";


}
- (IBAction)defaultButttonAction:(id)sender {
    [_logger debug:@"mxlogger" msg:@"这是info信息" tag:NULL];
    [_logger info:@"mxlogger" msg:@"这是info信息" tag:NULL];
    [_logger warn:@"mxlogger" msg:@"这是info信息" tag:NULL];
    [_logger error:@"mxlogger" msg:@"这是info信息" tag:NULL];
    [_logger fatal:@"mxlogger" msg:@"这是info信息" tag:NULL];
   
}
- (IBAction)tenThousandButtonAction:(id)sender {

    NSDate * dateStart=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval start =[dateStart timeIntervalSince1970];
    NSInteger index = 0;
    NSLog(@"开始写入日志");
 
    for (NSInteger i = 0; i < 100000; i++) {

        NSString * string = [NSString stringWithFormat:@"第%ld条数据",(long)i];
        [_logger info:@"name" msg:string tag:@"net"];
     
        
    }

    NSDate * dateEnd=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval end =[dateEnd timeIntervalSince1970];

    [sender setTitle:[NSString stringWithFormat:@"写10万条数据耗时:%f s",end-start] forState:UIControlStateNormal];
    NSLog(@"index = %ld",index);
    NSLog(@"时间:%f",end - start);
}


- (IBAction)logSizeButtonAction:(id)sender {
    NSUInteger logSize =   _logger.logSize;
      double size =  logSize/1024.0/1024.0;

    [sender setTitle:[NSString stringWithFormat:@"日志大小:%0.2fM",size] forState:UIControlStateNormal];
}

@end
