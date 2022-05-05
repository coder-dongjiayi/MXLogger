//
//  MXLogger.m
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//

#import "MXLogger.h"
#include <MXLoggerCore/mxlogger.hpp>
static NSMutableDictionary<NSString*,MXLogger *> *global_instanceDic = nil;
static NSString * _defaultDiskCacheDirectory;

@interface MXLogger()
{
    mx_logger *_logger;
    NSString * _nameSpace;
    NSString * _directory;
    
}
@property (nonatomic, copy, nonnull, readwrite) NSString *diskCachePath;
@property(nonatomic,assign,readwrite)BOOL isDebugTracking;
@property (nonatomic, strong, nullable) dispatch_queue_t ioQueue;

@end

@implementation MXLogger
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace{
  
    return [self initializeWithNamespace:nameSpace diskCacheDirectory:NULL];
}
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory{
 
    if (global_instanceDic == nil) {
        global_instanceDic = [NSMutableDictionary dictionary];
    }
  
    NSString * key =  [self mapKey:nameSpace diskCacheDirectory:directory];
    if ([global_instanceDic objectForKey:key] == nil) {
        MXLogger * logger = [[MXLogger alloc] initWithNamespace:nameSpace diskCacheDirectory:directory];
        [global_instanceDic setObject:logger forKey:key];
        return logger;
    }
    MXLogger * logger = [global_instanceDic objectForKey:key];
    return logger;
    
}
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace{
    [self destroyWithNamespace:nameSpace diskCacheDirectory:NULL];
}
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory{
    NSString * key =  [self mapKey:nameSpace diskCacheDirectory:directory];
    if ([global_instanceDic objectForKey:key]) {
        MXLogger * logger =  [global_instanceDic objectForKey:key];
        logger = nil;
        [global_instanceDic removeObjectForKey:key];
    }
}

+(NSString*)mapKey:(NSString*)nameSpace diskCacheDirectory:(NSString*)directory{
    
    if (!directory) {
        directory = [MXLogger defaultDiskCacheDirectory];
    }
    std::string mapKey =  mx_logger::md5(nameSpace.UTF8String, directory.UTF8String);
    
    NSString * key =  [NSString stringWithUTF8String:mapKey.data()];
    return key;
}


-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace{
    return [self initWithNamespace:nameSpace diskCacheDirectory:nil];
}
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory{
    if (self = [super init]) {
        if (!directory) {
            directory = [MXLogger defaultDiskCacheDirectory];
        }
        _nameSpace = nameSpace;
        _directory = directory;
        _logger =  mx_logger::initialize_namespace(nameSpace.UTF8String, directory.UTF8String);
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillTerminate:)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        _shouldRemoveExpiredDataWhenTerminate = YES;
        _shouldRemoveExpiredDataWhenEnterBackground = YES;
        NSString * queueName = [NSString stringWithFormat:@"com.mxlog.LoggerCache.%@",nameSpace];
        
        _ioQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
       
        
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    mx_logger::delete_namespace(_nameSpace.UTF8String, _directory.UTF8String);
    
}
/// 程序终止
- (void)applicationWillTerminate:(NSNotification *)notification {
   
    if (!self.shouldRemoveExpiredDataWhenTerminate) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self removeExpireData];
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
        [self removeExpireData];
        dispatch_async(dispatch_get_main_queue(), ^{
            [application endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        });
    });
}
- (BOOL)isDebugTracking{
    return _logger -> is_debug_tracking();
}
- (void)setStoragePolicy:(NSString *)storagePolicy{
    _storagePolicy = storagePolicy;
    _logger -> set_file_policy(storagePolicy.UTF8String);
}


- (void)setFileHeader:(NSDictionary *)fileHeader{
    _fileHeader = fileHeader;
    NSError * error;
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fileHeader options:NSJSONWritingPrettyPrinted error:&error];
    if (error != NULL || jsonData == NULL) {
        NSLog(@"header 资源转化失败");
        return;
    }
    
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    _logger -> set_file_header(jsonString.UTF8String);
}




- (void)setFileName:(NSString *)fileName{
    _fileName = fileName;
    _logger -> set_file_name(fileName.UTF8String);
}
-(void)setEnable:(BOOL)enable{
    _enable = enable;
    _logger -> set_enable(enable);
}
-(void)setConsoleEnable:(BOOL)consoleEnable{
    _consoleEnable = consoleEnable;
    _logger -> set_console_enable(consoleEnable);
}
-(void)setFileEnable:(BOOL)fileEnable{
    _fileEnable = fileEnable;
    _logger -> set_file_enable(fileEnable);
}
-(void)setMaxDiskAge:(NSUInteger)maxDiskAge{
    _maxDiskAge = maxDiskAge;
    
    _logger -> set_file_max_age([NSNumber numberWithUnsignedInteger:maxDiskAge].longValue);
    
}
- (void)setMaxDiskSize:(NSUInteger)maxDiskSize{
    _maxDiskSize = maxDiskSize;
    
    _logger -> set_file_max_size([NSNumber numberWithUnsignedInteger:maxDiskSize].longValue);
}

-(void)removeExpireData{
    _logger -> remove_expire_data();
}

-(void)removeAllData{
    _logger -> remove_all();
}

- (NSUInteger)logSize{
   long size =  _logger -> file_size();
    return [[NSNumber numberWithLong:size] unsignedIntegerValue];
}
- (void)setFileLevel:(NSInteger)fileLevel{
    _fileLevel = fileLevel;
    _logger -> set_file_level([NSNumber numberWithInteger:fileLevel].intValue);
}
- (void)setConsoleLevel:(NSInteger)consoleLevel{
    _consoleLevel = consoleLevel;
    
    _logger -> set_console_level([NSNumber numberWithInteger:consoleLevel].intValue);
}

- (void)setPattern:(NSString *)pattern{
    _pattern = pattern;
    if ([pattern isKindOfClass:[NSNull class]]) {
        return;
    }
    _logger -> set_pattern(pattern.UTF8String);
}
    


-(void)debug:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    [self log:0 name:name msg:msg tag:tag];
}
-(void)info:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    [self log:1 name:name msg:msg tag:tag];
}

-(void)warn:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    [self log:2 name:name msg:msg tag:tag];
}

-(void)error:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    [self log:3 name:name msg:msg tag:tag];
}

-(void)fatal:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    [self log:4 name:name msg:msg tag:tag];
}

-(void)log:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag {
    [self innerLogWithType:0 level:level name:name msg:msg tag:tag];
}

-(void)innerLogWithType:(NSInteger) type level:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag {
    BOOL isMainThread = [NSThread isMainThread];
  
    _logger -> log([NSNumber numberWithInteger:type].intValue, [NSNumber numberWithInteger:level].intValue,[name UTF8String], [msg UTF8String], [tag UTF8String], isMainThread);
}


- (NSString *)diskCachePath{
    return [NSString stringWithUTF8String:_logger->diskcache_path()];
}


// 默认缓存目录 library
+ (nullable NSString *)userCacheDirectory {
    
    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    return libraryPath;
}

+(NSString*)defaultDiskCacheDirectory{
    if(!_defaultDiskCacheDirectory){
        _defaultDiskCacheDirectory = [[self userCacheDirectory] stringByAppendingPathComponent:@"com.mxlog.LoggerCache"];
    }
    return _defaultDiskCacheDirectory;
}

@end
