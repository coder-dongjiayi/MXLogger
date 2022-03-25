//
//  MXLogger.m
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//

#import "MXLogger.h"
#include <MXLoggerCore/mxlogger_manager.hpp>

static NSString * _defaultDiskCacheDirectory;

@interface MXLogger()

@property (nonatomic, strong, nullable) dispatch_queue_t ioQueue;
@end

@implementation MXLogger
static MXLogger *_manager;

+(MXLogger*) shareManager{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[MXLogger alloc] init];
    });
    return _manager;
}


+(NSString*)defaultDiskCacheDirectory{
    if(!_defaultDiskCacheDirectory){
        _defaultDiskCacheDirectory = [[self userCacheDirectory] stringByAppendingPathComponent:@"com.mxlog.LoggerCache"];
    }
    return _defaultDiskCacheDirectory;
}
- (instancetype)init {
    
    return [self initWithNamespace:@"mxlog"];
}
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    return [self initWithNamespace:ns diskCacheDirectory:nil];
}


-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory{
    
    if (self = [super init]) {
        
        _ioQueue = dispatch_queue_create("com.mxlog.LoggerCache", DISPATCH_QUEUE_SERIAL);
        
        _shouldRemoveExpiredDataWhenEnterBackground = YES;
        _shouldRemoveExpiredDataWhenTerminate = YES;
        self.maxDiskAge = 0;
        self.maxDiskSize = 0;
        if (!directory) {
            directory = [MXLogger defaultDiskCacheDirectory];
        }
        _diskCachePath = [[directory stringByAppendingPathComponent:nameSpace] stringByAppendingString:@"/"];
        

        mx_logger &log =  mx_logger::instance();
        
        log.set_file_dir([_diskCachePath UTF8String]);
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
    }
    return self;

}


-(void)setMaxDiskSize:(NSUInteger)maxDiskSize{
    _maxDiskSize = maxDiskSize;
    mx_logger::instance().set_file_max_size(maxDiskSize);
}
-(void)setMaxDiskAge:(NSTimeInterval)maxDiskAge{
    _maxDiskAge = maxDiskAge;
    mx_logger::instance().set_file_max_age(maxDiskAge);
}
-(void)setStoragePolicy:(nonnull NSString *)storagePolicy{
    _storagePolicy = storagePolicy;
    if (storagePolicy == NULL) {
        return;
    }
    policy::storage_policy  storage_policy = policy::storage_policy::yyyy_MM_dd;
  
      if ([storagePolicy isEqualToString:@"yyyy_MM"]){
          storage_policy = policy::storage_policy::yyyy_MM;
      }else if([storagePolicy isEqualToString:@"yyyy_MM_dd"]){
          storage_policy = policy::storage_policy::yyyy_MM_dd;
      }else if ([storagePolicy isEqualToString:@"yyyy_ww"]){
          storage_policy = policy::storage_policy::yyyy_ww;
      }else if ([storagePolicy isEqualToString:@"yyyy_MM_dd_HH"]){
          storage_policy =  policy::storage_policy::yyyy_MM_dd_HH;
      }
    mx_logger::instance().set_file_policy(storage_policy);
}
-(void)setFileName:(nonnull NSString *) fileName{
    _fileName = fileName;
    mx_logger::instance().set_file_name([fileName UTF8String]);
}

-(void)setConsolePattern:(NSString *)consolePattern{
    _consolePattern = consolePattern;
    mx_logger::instance().set_console_pattern([consolePattern UTF8String]);
}
-(void)setFilePattern:(NSString *)filePattern{
    _filePattern = filePattern;
    mx_logger::instance().set_file_pattern([filePattern UTF8String]);
}

-(void)setFileHeader:(NSString *)fileHeader{
    _fileHeader = fileHeader;
    mx_logger::instance().set_file_header([fileHeader UTF8String]);
}
- (NSUInteger)logSize{
   
    return mx_logger::instance().file_size();
}
- (bool)isDebugTraceing{
    return mx_logger::instance().is_debuging();
}

- (void)setConsoleLevel:(NSInteger)consoleLevel{
    _consoleLevel = consoleLevel;
    [self setLevel:0 levle:consoleLevel];
    
}
-(void)setFileLevel:(NSInteger)fileLevel{
    _fileLevel = fileLevel;
    [self setLevel:1 levle:fileLevel];
}
-(void)setConsoleEnable:(BOOL)consoleEnable{
    _consoleEnable = consoleEnable;
    mx_logger::instance().set_console_enable(consoleEnable);
}
-(void)setFileEnable:(BOOL)fileEnable{
    _fileEnable = fileEnable;
    mx_logger::instance().set_file_enable(fileEnable);
}
- (void)setIsAsync:(BOOL)isAsync{
    _isAsync = isAsync;
    mx_logger::instance().set_file_async(isAsync);
}
-(void)setLevel:(NSInteger)type levle:(NSInteger)lvl{
    level::level_enum l = [MXLogger _level:lvl];
    
    if (type == 0) {
        mx_logger::instance().set_console_level(l);
    }else{
        mx_logger::instance().set_file_level(l);
    }
}
// 默认缓存目录 library
+ (nullable NSString *)userCacheDirectory {
    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return libraryPath;
}

/// 程序终止
- (void)applicationWillTerminate:(NSNotification *)notification {
   
    if (!self.shouldRemoveExpiredDataWhenTerminate) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [MXLogger removeExpireData];
    });
}
/// 进入后台
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    if (!self.shouldRemoveExpiredDataWhenEnterBackground) {
        return;
    }
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
       
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    dispatch_async(self.ioQueue, ^{
        [MXLogger removeExpireData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        });
    });
}

+(void)logFile:(NSString* _Nullable)name level:(NSInteger)level msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [[MXLogger shareManager] inner_log:2 name:name level:level  msg:msg tag:tag];
}


+(void)log:(NSString* _Nullable)name level:(NSInteger)level msg:(NSString*)msg tag:(NSString* _Nullable)tag{
   
    [[MXLogger shareManager] inner_log:0  name:name level:level  msg:msg tag:tag];
}

/// 只写入文件 (异步)

+(void)asyncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [[MXLogger shareManager] inner_asyncLogFile:name level:level msg:msg tag:tag];
}
/// 只写入文件 (同步)
+(void)syncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [[MXLogger shareManager] inner_syncLogFile:name level:level msg:msg tag:tag];
}

-(void)inner_asyncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    BOOL isMainThread = [NSThread currentThread].isMainThread;
  
    mx_logger::instance().log_async_file([MXLogger _level:level], [name UTF8String], [msg UTF8String], [tag UTF8String],isMainThread);
}

-(void)inner_syncLogFile:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    BOOL isMainThread = [NSThread currentThread].isMainThread;
    mx_logger::instance().log_sync_file([MXLogger _level:level], [name UTF8String], [msg UTF8String], [tag UTF8String],isMainThread);
}

-(void)inner_log:(NSInteger)log_type name:(NSString* _Nullable)name level:(NSInteger)level  msg:(NSString*)msg tag:(NSString* _Nullable)tag{
 
    
    BOOL isMainThread = [NSThread currentThread].isMainThread;
    
  
    mx_logger::instance().log([MXLogger _logType:log_type],[MXLogger _level:level], [name UTF8String], [msg UTF8String], [tag UTF8String],isMainThread);
    
   
}

+(mxlogger::log_type) _logType:(NSInteger)type{
    mxlogger::log_type _type = mxlogger::log_type::all;
    
    switch (type) {
        case 0:
            _type = mxlogger::log_type::all;
            break;
        case 1:
            _type = mxlogger::log_type::console;
            break;
        case 2:
            _type = mxlogger::log_type::file;
            break;
        default:
            break;
    }
    return _type;
}
+(level::level_enum) _level:(NSInteger)level{
    level::level_enum lvl = level::level_enum::debug;
    switch (level) {
        case 0:
            lvl = level::level_enum::debug;
            break;
        case 1:
            lvl = level::level_enum::info;
            break;
        case 2:
            lvl = level::level_enum::warn;
            break;
        case 3:
            lvl = level::level_enum::error;
            break;
        case 4:
            lvl = level::level_enum::fatal;
            
        default:
            break;
    }
    return lvl;
}
+(void) removeExpireData{
    mx_logger::instance().remove_expire_data();
}


+(void) removeAll{
    mx_logger::instance().remove_all();
}


+(void)debug:(NSString*)msg{
    [self debug:msg tag:NULL];
}

+(void)debug:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:NULL level:0 msg:msg tag:tag];
   
}
+(void)debug:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:name level:0 msg:msg tag:tag];
}
+(void)info:(NSString*)msg{
    [self info:msg tag:NULL];
}
+(void)info:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:NULL level:1 msg:msg tag:tag];
}
+(void)info:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:name level:1 msg:msg tag:tag];
}
+(void)warn:(NSString*)msg{
    [self warn:msg tag:NULL];
}
+(void)warn:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:NULL level:2 msg:msg tag:tag];
}
+(void)warn:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:name level:2 msg:msg tag:tag];
}

+(void)error:(NSString*)msg{
    [self error:msg tag:NULL];
}
+(void)error:(NSString*)msg tag:(NSString* _Nullable)tag{

    [self log:NULL level:3 msg:msg tag:tag];
}
+(void)error:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:name level:3 msg:msg tag:tag];
}

+(void)fatal:(NSString*)msg{
    [self fatal:msg tag:NULL];
}
+(void)fatal:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:NULL level:4 msg:msg tag:tag];
}
+(void)fatal:(NSString* _Nullable)name msg:(NSString*)msg tag:(NSString* _Nullable)tag{
    [self log:name level:4 msg:msg tag:tag];
}
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    @synchronized (self) {
        if (_manager == nil) {
            _manager = [super allocWithZone:zone];
            return _manager;
        }
    }
    return _manager;
}
- (id)copy{
    return self;
}
- (id)mutableCopy{
    return self;
}

@end
