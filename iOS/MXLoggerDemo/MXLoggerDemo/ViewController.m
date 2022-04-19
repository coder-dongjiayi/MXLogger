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
    
    _logger =   [[MXLogger alloc] initWithNamespace:@"default2" diskCacheDirectory:NULL];
     NSLog(@"日志文件磁盘缓存目录:%@",_logger.diskCachePath);
    _logger.storagePolicy = @"yyyy_MM_dd";
    _logger.fileName = @"mxlog";
    _logger.fileHeader =  @"版本号:1.0.0 平台:iOS";
    
//    [MXLogger testMXLogger:@"user/test/ssss"];
//    [MXLogger shareManager].fileHeader = @"版本号:1.0.0 平台:iOS";
//    [MXLogger shareManager].maxDiskAge = 60 * 60 * 24 * 7; // 一个星期
//    [MXLogger shareManager].maxDiskSize = 1024 * 1024 * 100; // 100M
//
//    NSString * path = [MXLogger shareManager].diskCachePath;
//
//    [MXLogger debug:[NSString stringWithFormat:@"日志文件路径:%@",path]];
//    /**下面这些设置都是默认设置 不写也行 **/
//
//    [MXLogger shareManager].storagePolicy = @"yyyy_MM_dd";
//
//    [MXLogger shareManager].shouldRemoveExpiredDataWhenEnterBackground = YES;
//
//    [MXLogger shareManager].shouldRemoveExpiredDataWhenTerminate = YES;
//
//    [MXLogger shareManager].fileName = @"mxlog";
//
//    [MXLogger shareManager].consoleLevel = 0;
//    /// 默认情况下 debug数据不会写入到文件中 如果设置 [BlingLogger shareManager].fileLevel = 0 那么debug数据才会写入到日志文件
//    [MXLogger shareManager].fileLevel = 1;
//
//    //设置为NO 控制台不再打印数据
//    [MXLogger shareManager].consoleEnable = YES;
   // 2022-04-19 11:33:27.606018+0800
//    //设置为NO 不再写入日志文件
//    [MXLogger shareManager].fileEnable = YES;
//
//    //控制台输出格式
//    [MXLogger shareManager].consolePattern = @"[%d][%p]%m";
//    //文件输出格式
//    [MXLogger shareManager].filePattern = @"[%d][%t][%p]%m";
//
//    [MXLogger shareManager].isAsync = YES;
}
- (IBAction)defaultButttonAction:(id)sender {
//    [MXLogger debug:@"这是一条debug,会输出到控制台" tag:@"TAG"];
//    [MXLogger info:@"这是一条infoLog,会输出到控制台"];
//    [MXLogger warn:@"这是一条warn,会输出到控制台"];
//    [MXLogger error:@"这是一条error,会输出到控制台"];
//    [MXLogger fatal:@"这是一条fatal,会输出到控制台"];
   
}
- (IBAction)tenThousandButtonAction:(id)sender {
    /// 同步写入测试
//    [MXLogger shareManager].isAsync = NO;
//
    NSDate * dateStart=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval start =[dateStart timeIntervalSince1970];
    NSLog(@"开始写入日志");
    for (int i = 0; i < 100000; i++) {

        NSString * string = [NSString stringWithFormat:@"第%d条数据",i];
        [_logger info:@"name" msg:string tag:@"tag"];
    }

    NSDate * dateEnd=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval end =[dateEnd timeIntervalSince1970];

    [sender setTitle:[NSString stringWithFormat:@"写10万条数据耗时:%f s",end-start] forState:UIControlStateNormal];

    NSLog(@"时间:%f",end - start);
}

- (IBAction)syncButtonAction:(id)sender {
//    [MXLogger syncLogFile:NULL level:1 msg:@"这是同步方法，只写入文件不会输出到控制台" tag:NULL];
}
- (IBAction)asyncButtonAction:(id)sender {
//    [MXLogger asyncLogFile:NULL level:1 msg:@"这是异步方法，只写入文件不会输出到控制台" tag:NULL];
}
- (IBAction)logSizeButtonAction:(id)sender {
//    NSUInteger logSize =   [MXLogger shareManager].logSize;
//      double size =  logSize/1024.0/1024.0;
//
//    [sender setTitle:[NSString stringWithFormat:@"日志大小:%0.2fM",size] forState:UIControlStateNormal];
}

@end
