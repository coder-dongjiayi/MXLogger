//
//  MXLogger.m
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//

#import "MXLogger.h"
#include <MXLoggerCore/mxlogger.hpp>
#include <MXLoggerCore/mxlogger_util.hpp>
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
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory {
 
    if (global_instanceDic == nil) {
        global_instanceDic = [NSMutableDictionary dictionary];
    }
  
    NSString * key =  [self mapKey:nameSpace diskCacheDirectory:directory];
    if ([global_instanceDic objectForKey:key] == nil) {
        MXLogger * logger = [[MXLogger alloc] initWithNamespace:nameSpace diskCacheDirectory:directory storagePolicy:nil fileName:nil];
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
+(NSArray<NSDictionary*>*)selectWithDiskCacheFilePath:(nonnull NSString*)diskCacheFilePath{

  
  
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::util::mxlogger_util::select_log_form_path(diskCacheFilePath.UTF8String, &destination);
    
    if(destination.size() == 0) return @[];
    
    NSMutableArray<NSDictionary*> *messageList = [NSMutableArray arrayWithCapacity:destination.size()];
    
    for (int i = (int)(destination.size() - 1); i>=0; i--) {
        
        std::map<std::string,std::string> log_map = destination[i];
        
       std::string  msg = log_map["msg"];
        std::string name = log_map["name"];
        std::string tag = log_map["tag"];
        std::string is_main_thread = log_map["is_main_thread"];
        std::string timestamp = log_map["timestamp"];
        std::string level = log_map["level"];
        

        
        NSDictionary * dictionary = @{
            @"msg":[NSString stringWithUTF8String:msg.data()],
            @"name":[NSString stringWithUTF8String:name.data()],
            @"tag":[NSString stringWithUTF8String:tag.data()],
            @"is_main_thread":[NSString stringWithUTF8String:is_main_thread.data()],
            @"timestamp":[NSString stringWithUTF8String:timestamp.data()],
            @"level":[NSString stringWithUTF8String:level.data()]
            
        };
        
        [messageList addObject:dictionary];
    }

    return [messageList copy];
   
}
+(NSArray<NSDictionary<NSString*,NSString*>*>*)selectLogfilesWithDirectory:(nonnull NSString*)directory{
   
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::util::mxlogger_util::select_logfiles_dir(directory.UTF8String, &destination);
    
    NSMutableArray<NSDictionary<NSString*,NSString*>*>* files = [NSMutableArray arrayWithCapacity:destination.size()];
    
    for (int i = 0; i< destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        NSString * name = [NSString stringWithUTF8String:map["name"].data()];
        NSString * size = [NSString stringWithUTF8String:map["size"].data()];
        NSString * timestamp = [NSString stringWithUTF8String:map["timestamp"].data()];
        
        NSDictionary *dictionary = @{@"name":name,@"size":size,@"timestamp":timestamp};
        
        [files addObject:dictionary];
    }
  
    
    return [files copy];
}



-(instancetype)initWithNamespace:(NSString *)nameSpace diskCacheDirectory:(NSString *)directory{
    return [self initWithNamespace:nameSpace diskCacheDirectory:directory storagePolicy:nil fileName:nil];
}

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace{
    return [self initWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:nil fileName:nil];
}
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName{
    if (self = [super init]) {
        if (!directory) {
            directory = [MXLogger defaultDiskCacheDirectory];
        }
        _nameSpace = nameSpace;
        _directory = directory;
        
        const char * file_name = fileName == NULL ? nullptr : fileName.UTF8String;
        const char * storage_policy = storagePolicy == NULL ? nullptr : storagePolicy.UTF8String;
        
        
        _logger =  mx_logger::initialize_namespace(nameSpace.UTF8String, directory.UTF8String,storage_policy,file_name);
        
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
    self->_logger->flush();
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
    self->_logger->flush();
    
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




-(void)setEnable:(BOOL)enable{
    _enable = enable;
    _logger -> set_enable(enable);
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
   long size =  _logger -> dir_size();
    return [[NSNumber numberWithLong:size] unsignedIntegerValue];
}
- (void)setFileLevel:(NSInteger)fileLevel{
    _fileLevel = fileLevel;
    _logger -> set_file_level([NSNumber numberWithInteger:fileLevel].intValue);
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
  
    int type_ = [NSNumber numberWithInteger:type].intValue;
    int level_ = [NSNumber numberWithInteger:level].intValue;
   
    const char* name_ = [self isNull:name] == YES ? nullptr : name.UTF8String;
    const char* tag_ = [self isNull:tag] == YES ? nullptr : tag.UTF8String;
    const char* msg_ = [self isNull:msg] == YES ? nullptr : msg.UTF8String;
    
    _logger -> log(type_, level_,name_, msg_, tag_, isMainThread);
}

-(BOOL)isNull:(NSString*) object{
    if (object == NULL) {
        return YES;
    }
    if ([object isKindOfClass:[NSNull class]]) {
        return YES;
    }
    return NO;
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
