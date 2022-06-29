//
//  LogViewController.m
//  MXLoggerDemo
//
//  Created by 董家祎 on 2022/6/24.
//

#import "LogViewController.h"
#import "LogListViewController.h"
#import <MXLogger/MXLogger.h>
@interface LogViewController ()
{
    NSString * _cryptKey;
    NSString * _iv;
}
@property(nonatomic,strong)MXLogger * logger;
@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *filesLabel;

@end

@implementation LogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _cryptKey = @"mxloggeraes128cryptkey";
    _iv = @"mxloggeraescfbiv";
    [self initMXLogger];
    [self updateSize];
}

-(void)initMXLogger{
   self.logger =  [MXLogger initializeWithNamespace:@"com.dongjiayi.mxlogger" storagePolicy:@"yyyy_MM_dd_HH" fileName:@"mxlogger" cryptKey:_cryptKey iv:_iv];

    // 使用实例构造器初始化
//    self.logger = [[MXLogger alloc] initWithNamespace:@"com.dongjiayi.mxlogger" cryptKey:_cryptKey iv:_iv];
    
    self.logger.maxDiskAge = 60*60*24*7; // 一个星期
    self.logger.maxDiskSize = 1024 * 1024 * 10; // 10M
    
    self.logger.shouldRemoveExpiredDataWhenEnterBackground = YES;

    self.logger.shouldRemoveExpiredDataWhenTerminate = YES;

    self.logger.consoleEnable = NO;
    
    self.logger.level = 0;

    NSLog(@"目录:%@",self.logger.diskCachePath);
    
}
- (IBAction)writeLogButtonAction:(id)sender {
 
    [self.logger debug:NULL msg:@"这是debug信息" tag:@"net"];
    [self.logger debug:@"mxlogger" msg:@"这是debug信息" tag:@"response"];
    [self.logger info:@"mxlogger" msg:@"这是info信息" tag:@"request"];
    [self.logger warn:@"mxlogger" msg:@"这是warn信息" tag:@"step"];
    [self.logger error:@"mxlogger" msg:@"这是error信息" tag:NULL];
    [self.logger fatal:@"mxlogger" msg:@"这是fatal信息" tag:NULL];
    [self updateSize];
}


- (IBAction)onehundredthousandButtonAction:(id)sender {
    
    NSDate * dateStart=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval start =[dateStart timeIntervalSince1970];

    for (NSInteger i = 0; i < 1000000; i++) {


        [self.logger info:@"name" msg:@"This is mxlogger log" tag:@"net"];

    }
    NSDate * dateEnd=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval end =[dateEnd timeIntervalSince1970];

    [sender setTitle:[NSString stringWithFormat:@"写10万条数据耗时:%f s",end-start] forState:UIControlStateNormal];

    NSLog(@"时间:%f",end - start);
    [self updateSize];
}
- (IBAction)logFileButtonAction:(id)sender {
    NSMutableArray<NSString*> * filesArray = [NSMutableArray array];
    
    NSArray * array =   [MXLogger selectLogfilesWithDirectory:_logger.diskCachePath];
      [array enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
          NSString * str = [NSString stringWithFormat:@"name:%@ size:%@,timestamp:%@",obj[@"name"],obj[@"size"],obj[@"timestamp"]];
          [filesArray addObject:str];
          
      }];
    if(array.count == 0){
        self.filesLabel.text = @"没有日志文件";
    }else{
        self.filesLabel.text = [filesArray componentsJoinedByString:@"\n"];
    }
   
}


- (IBAction)removeExpireDataButtonAction:(id)sender {
    [self.logger removeExpireData];
}

- (IBAction)removeAllButtonAction:(id)sender {
    [self.logger removeAllData];
}

-(void)updateSize{
    NSUInteger logSize =   self.logger.logSize;
    double size =  logSize/1024.0/1024.0;

    self.sizeLabel.text = [NSString stringWithFormat:@"当前日志大小:%0.2f MB",size];
    NSLog(@"日志字节大小:%ld byte",logSize);
}

- (IBAction)lookButtonAction:(id)sender {
    LogListViewController * controller = [[LogListViewController alloc] initWithNibName:nil bundle:nil];
    controller.dirPath = self.logger.diskCachePath;
    controller.cryptKey = _cryptKey;
    controller.iv = _iv;
    [self.navigationController pushViewController:controller animated:YES];
}


- (void)dealloc{
    
    [MXLogger destroyWithNamespace:@"com.dongjiayi.mxlogger"];
}

@end
