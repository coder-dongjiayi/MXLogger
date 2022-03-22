//
//  BlingLogger.h
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN


@interface BlingLogger : NSObject


+(BlingLogger*) shareManager;


-(nonnull instancetype)initWithNamespace:(nonnull NSString *)ns;

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory;

/*
 日志文件存储策略
 yyyy_MM_dd 每天存储一个日志文件
 yyyy_ww    每周存储一个日志文件
 yyyy_MM  每个月存储一个日志文件
 yyyy_MM_dd_HH 每小时存储一个日志文件
 
 默认值: yyyy_MM_dd
 **/

@property(nonatomic,copy,nonnull) NSString * storagePolicy;

/*
 %d 日志生成时间
 %p 日志等级
 %t 线程id
 %m 日志信息 msg
 */
///  控制台输出格式化  [%d][%p]%m

@property(nonatomic,copy,nonnull) NSString * consolePattern;

/// 写入文件格式化  [%d][%t][%p]%m

@property(nonatomic,copy,nonnull) NSString * filePattern;
/*
  参数：
    0:debug
    1:info
    2:warn
    3:error
    4:fatal
 **/
/// 设置控制台输出日志等级 默认 0(debug)
@property (nonatomic,assign)NSInteger  consoleLevel;
/// 设置写入日志文件等级  默认1( info)
@property (nonatomic,assign)NSInteger  fileLevel;

/// 开启/禁用控制台日志输出
///  默认情况下 如果当前设备连接Xcode正在调试，那么 consoleEnable = YES，会在控制台输出日志。非调试状态下不会把日志输出到控制台
@property (nonatomic,assign)BOOL consoleEnable;
/// 开启/禁用日志写入 默认YES
@property (nonatomic,assign)BOOL fileEnable;

/// 设置每次创建文件的时候 写入的文件头信息 比如可以把当前设备型号，用户信息等等 写进去
@property(nonatomic,copy,nonnull) NSString * fileHeader;

/*
  设置文件名，配合storagePolicy字段，如果 fileName =@"appname" storagePolicy = @“yyyy_MM_dd”
 那么最终存储的文件名为 appname_2022-03-15.log
 
 默认值:blinglog
 **/
@property(nonatomic,copy,nonnull)NSString * fileName;

// 获取日志文件的磁盘缓存路径
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;

// 是否在程序进入后台的时候清理过期文件 默认YES;
@property (assign, nonatomic) BOOL shouldRemoveExpiredDataWhenEnterBackground;

// 是否在程序退出的时候清理过期文件 默认 YES;
@property(nonatomic,assign)BOOL shouldRemoveExpiredDataWhenTerminate;

// 日志文件最大存储时长(s) 默认0  不限制 比如 60 * 60 *24 *7 就是一星期
@property (assign, nonatomic) NSTimeInterval maxDiskAge;

// 日志文件最大存储字节数(byte) 默认为0 不限制 比如 1024 * 1024 * 10 就是 10M
@property (assign, nonatomic) NSUInteger maxDiskSize;

// 日志文件大小(byte)
@property (nonatomic,assign,readonly) NSUInteger logSize;

// 是否正在被调试
@property (nonatomic,assign,readonly) BOOL isDebugTraceing;

// 日志写入同步还是异步 默认异步(控制台打印全都是同步，不支持异步)
@property (nonatomic,assign)BOOL isAsync;



/// 输出日志 (输出到控制台并写入到文件) 默认异步 可以通过 isAsync 进行更改
/// @param level 0 (debug) 1(info) 2(warn) 3(error) 4(fatal)
/// @param name 前缀
/// @param msg msg
/// @param tag tag
+(void)log:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag;

/// 只写入文件 不输出到控制台 默认异步 通过 isAsync设置
+(void)logFile:(NSString* _Nullable)name level:(NSInteger)level msg:(NSString*)msg tag:(NSString* _Nullable)tag;


/*
 下面这两个方法提供给使用者，进行自定义封装 isAsync 对下面的方法无效，默认情况下写入日志是异步的，但是如果抓取crash日志这种
 操作， 可以直接调用 syncLogFile
 */
/// 只写入文件 (异步)
+(void)asyncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag;
/// 只写入文件 (同步)
+(void)syncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag;


//删除过期日志文件 多线程不安全 
+(void) removeExpireData;
//删除所有日志文件 多线程不安全
+(void) removeAll;


+(void)debug:(NSString*)msg;

+(void)debug:(NSString*)msg tag:(NSString* _Nullable)tag;

+(void)debug:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag;


+(void)info:(NSString*)msg;
+(void)info:(NSString*)msg tag:(NSString* _Nullable)tag;

+(void)info:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag;

+(void)warn:(NSString*)msg;
+(void)warn:(NSString*)msg tag:(NSString* _Nullable)tag;

+(void)warn:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag;



+(void)error:(NSString*)msg;

+(void)error:(NSString*)msg tag:(NSString* _Nullable)tag;
+(void)error:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag;


+(void)fatal:(NSString*)msg;

+(void)fatal:(NSString*)msg tag:(NSString* _Nullable)tag;
+(void)fatal:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag;

@end

NS_ASSUME_NONNULL_END
