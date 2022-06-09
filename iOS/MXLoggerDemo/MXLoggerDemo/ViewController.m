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

   
    _logger.maxDiskAge = 60; // 一个星期
    _logger.maxDiskSize = 1024 * 1024 * 10; // 10M
    

    _logger.shouldRemoveExpiredDataWhenEnterBackground = YES;

    _logger.shouldRemoveExpiredDataWhenTerminate = YES;


    _logger.fileLevel = 0;

    NSLog(@"目录:%@",_logger.diskCachePath);
    

}



- (IBAction)cacheDirButtonAction:(id)sender {
  NSArray * array =   [MXLogger selectLogfilesWithDirectory:_logger.diskCachePath];
    [array enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"文件名:%@,文件大小:%@,文件最后更新时间:%@",obj[@"name"],obj[@"size"],obj[@"timestamp"]);
    }];
}

- (IBAction)removeAllButtonAction:(id)sender {
   
    
    [_logger removeAllData];
}


- (IBAction)removeExpireDataButtonAction:(id)sender {
    [_logger removeExpireData];
}

- (IBAction)readLogButtonAction:(id)sender {

    NSArray * array =   [MXLogger selectLogfilesWithDirectory:_logger.diskCachePath];

    NSString * path = [NSString stringWithFormat:@"%@%@",_logger.diskCachePath,array.firstObject[@"name"]];

   NSArray * result =  [MXLogger selectWithDiskCacheFilePath:path];

    [result enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * msg = obj[@"msg"];
        NSString * tm = obj[@"timestamp"];
        NSString * tag = obj[@"tag"];
        NSString * name = obj[@"name"];
        NSString * level = obj[@"level"];
        NSString *  is_main = obj[@"is_main_thread"];
        NSString * threadId = obj[@"thread_id"];
        NSLog(@"[%@] tm:%@,msg:%@,tag:%@,level:%@ thread_id=%@ is_main=%@",name,tm,msg,tag,level,threadId,is_main);
    }];
}

- (IBAction)defaultButttonAction:(id)sender {
    [_logger debug:NULL msg:@"这是debug信息" tag:NULL];
    [_logger debug:@"mxlogger" msg:@"这是debug信息" tag:NULL];
    [_logger info:@"mxlogger" msg:@"这是info信息" tag:NULL];
    [_logger warn:@"mxlogger" msg:@"这是warn信息" tag:NULL];
    [_logger error:@"mxlogger" msg:@"这是error信息" tag:NULL];
    [_logger fatal:@"mxlogger" msg:@"这是fatal信息" tag:NULL];
   
}
- (IBAction)tenThousandButtonAction:(id)sender {

  
    
    NSDate * dateStart=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval start =[dateStart timeIntervalSince1970];
    NSInteger index = 0;
    NSLog(@"开始写入日志");
    for (NSInteger i = 0; i < 100000; i++) {

       NSString * message = [NSString stringWithFormat:@"第%ld条数据",(long)i];

        [self->_logger info:@"name" msg:message tag:@"net"];

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
