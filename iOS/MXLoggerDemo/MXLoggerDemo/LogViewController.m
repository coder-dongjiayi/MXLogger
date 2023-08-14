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

    
    _cryptKey = @"abcdefgabcdefgob";
    _iv = @"abcdefgabcdefgcc";
    [self initMXLogger];
    [self updateSize];
}

-(void)initMXLogger{
    NSDictionary * dic = @{
        @"platform":@"iOS",
        @"vdersion":@"3.8.0",
        @"device":@"iphone8",
        @"disk":@"剩余磁盘空间300M",
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:NULL];

  NSString*  jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];

   self.logger =  [MXLogger initializeWithNamespace:@"com.djy.mxlogger" storagePolicy:MXStoragePolicyYYYYMMDDHH fileName:NULL fileHeader:jsonString cryptKey:_cryptKey iv:_iv];

    // 使用实例构造器初始化
//    self.logger = [[MXLogger alloc] initWithNamespace:@"com.dongjiayi.mxlogger" cryptKey:_cryptKey iv:_iv];
    
    self.logger.maxDiskAge = 60*60*24*7; // 一个星期
    self.logger.maxDiskSize = 1024 * 1024 * 10; // 10M

    self.logger.shouldRemoveExpiredDataWhenEnterBackground = YES;


    self.logger.consoleEnable = NO;
    
    self.logger.level = 0;
    
    

    MXLogger * lg = [MXLogger valueForLoggerKey:self.logger.loggerKey];
    NSLog(@"self.logger:%@",self.logger);
    NSLog(@"MXLogger: %@",lg);
    
    NSLog(@"目录:%@",self.logger.diskCachePath);
    
  
}


- (IBAction)writeLogButtonAction:(id)sender {
  
    NSDictionary * dict = @{
        @"uri":@"https://192.168.1.1/test",
        @"method":@"POST",
        @"responseType":@"ResponseType.json",
        @"followRedirects":@"true",
        @"connectTimeout":@"0",
        @"receiveTimeout":@"0",
        @"Request headers":@"{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
        @"Request data":@"{mobile: 6666666666, logUrl: https://xxxx.txt}",
        @"statusCode":@"200",
        @"Response Text":@"{\"code\":0,\"msg\":\"操作成功\"}"
    };
   NSData * data =  [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:NULL];
  NSString * jsonString =   [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    
//    [self.logger debug:@"mxlogger" msg:jsonString tag:@"response,request,other"];
    [self.logger debugWithName:@"mxlogger" msg:@"这是debug信息" tag:NULL];
    [self.logger infoWithName:@"mxlogger" msg:@"MXLogger 是基于mmap内存映射机制的跨平台日志库，支持AES CFB 128位加密，支持iOS Android Flutter。核心代码使用C/C++实现， Flutter端通过ffi调用，性能几乎与原生一致。 底层序列化使用Google开源的flat_buffers实现，高效稳定" tag:@"request"];
    [self.logger warnWithName:NULL msg:@"这是warn信息" tag:@"step"];
    [self.logger errorWithName:@"app" msg:@"这是error信息" tag:NULL];
    [self.logger fatalWithName:@"mxlogger" msg:@"这是fatal信息" tag:NULL];
    [self updateSize];
}


- (IBAction)onehundredthousandButtonAction:(id)sender {
    
   
    
    NSDate * dateStart=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval start =[dateStart timeIntervalSince1970];

    for (NSInteger i = 0; i < 100000; i++) {
        // 单条数据序列化之后的大小为136个字节 可以debug mmap_sink.cpp 中的第63行获取size的大小

        [self.logger infoWithName:@"name" msg:@"This is test looooooooooooooooooooooooooooooooog" tag:@"net"];

    }
    NSDate * dateEnd=   [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval end =[dateEnd timeIntervalSince1970];

    [sender setTitle:[NSString stringWithFormat:@"mxlogger写10万条数据耗时:%f s",end-start] forState:UIControlStateNormal];

    NSLog(@"时间:%f",end - start);
    [self updateSize];
}
- (IBAction)threadTestButtonAction:(id)sender {
    
    dispatch_queue_t queue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        for (int i=0; i<10; i++) {
            
            [self.logger infoWithName:NULL msg:[NSString stringWithFormat:@"queue1 index=%ld",i] tag:@"queue1"];
            NSLog(@"%@",[NSString stringWithFormat:@"queue1 index=%ld",i]);
        }
        
    });
    
    dispatch_async(queue, ^{
        for (int i=0; i<8; i++) {
            
            [self.logger infoWithName:NULL msg:[NSString stringWithFormat:@"queue2 index=%ld",i] tag:@"queue2"];
            NSLog(@"%@",[NSString stringWithFormat:@"queue2 index=%ld",i]);
        }
        
    });
    dispatch_async(queue, ^{
        for (int i=0; i<12; i++) {
            
            [self.logger infoWithName:NULL msg:[NSString stringWithFormat:@"queue3 index=%ld",i] tag:@"queue3"];
            NSLog(@"%@",[NSString stringWithFormat:@"queue3 index=%ld",i]);
        }
    });

    
}


- (IBAction)logFileButtonAction:(id)sender {
    NSMutableArray<NSString*> * filesArray = [NSMutableArray array];
    
    NSArray * array =   [self.logger logFiles];
      [array enumerateObjectsUsingBlock:^(NSDictionary*  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
          NSString * str = [NSString stringWithFormat:@"name:%@ size:%@,create:%@ last:%@",obj[@"name"],obj[@"size"],obj[@"create_timestamp"],obj[@"last_timestamp"]];
          [filesArray addObject:str];
          
      }];
    if(array.count == 0){
        self.filesLabel.text = @"没有日志文件";
    }else{
        self.filesLabel.text = [filesArray componentsJoinedByString:@"\n"];
    }
   
}
- (IBAction)removeBeforeAllButtonAction:(id)sender {
    [self.logger removeBeforeAllData];
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
    controller.loggerKey = self.logger.loggerKey;
    controller.iv = _iv;
    [self.navigationController pushViewController:controller animated:YES];
}


- (void)dealloc{
    
    [MXLogger destroyWithNamespace:@"com.djy.mxlogger"];
}

@end
