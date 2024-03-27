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
@property (nonatomic,copy,nonnull,readwrite)NSString* loggerKey;

@end

@implementation MXLogger
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace{
    return  [self initializeWithNamespace:nameSpace fileHeader:nil];
}
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder{
  
    return [self initializeWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:MXStoragePolicyYYYYMMDD fileName:nil  fileHeader:fileHeder  cryptKey:nil iv:nil];
}
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder {
    return [self initializeWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:MXStoragePolicyYYYYMMDD fileName:nil  fileHeader:fileHeder  cryptKey:cryptKey iv:iv];
}
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName  fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv{
    return [self initializeWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:storagePolicy fileName:fileName  fileHeader:fileHeder  cryptKey:cryptKey iv:iv];
}
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory  storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv{
 
    if (global_instanceDic == nil) {
        global_instanceDic = [NSMutableDictionary dictionary];
    }
  
    NSString * key =  [self mapKey:nameSpace diskCacheDirectory:directory];
    if ([global_instanceDic objectForKey:key] == nil) {
        MXLogger * logger = [[MXLogger alloc] initWithNamespace:nameSpace diskCacheDirectory:directory storagePolicy:storagePolicy fileName:fileName fileHeader:fileHeder  cryptKey:cryptKey iv:iv];
      
        return logger;
    }
    MXLogger * logger = [global_instanceDic objectForKey:key];
    
    return logger;
    
}


+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString *)fileHeder{
    return [self initializeWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:storagePolicy fileName:fileName fileHeader:fileHeder cryptKey:nil iv:nil];
}


+(void)destroyWithNamespace:(nonnull NSString*)nameSpace{
    [self destroyWithNamespace:nameSpace diskCacheDirectory:[MXLogger defaultDiskCacheDirectory]];
}
+(void)destroyWithLoggerKey:(nonnull NSString*)loggerKey{
    
    if ([global_instanceDic objectForKey:loggerKey]) {
        MXLogger * logger =  [global_instanceDic objectForKey:loggerKey];
        
        logger = nil;
        [global_instanceDic removeObjectForKey:loggerKey];
    }
    
    mx_logger::delete_namespace(loggerKey.UTF8String);
}
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory{
    
    NSString * key =  [self mapKey:nameSpace diskCacheDirectory:directory];
    
    [self destroyWithLoggerKey:key];
    
}
+(MXLogger*)valueForLoggerKey:(NSString*)loggerKey{
    if(loggerKey == NULL || [loggerKey isKindOfClass:[NSNull class]]){
        return NULL;
    }
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
    return logger;
}

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder {
    
    return [self initWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:MXStoragePolicyYYYYMMDD fileName:nil fileHeader:fileHeder cryptKey:cryptKey iv:iv];
}
-(instancetype)initWithNamespace:(NSString *)nameSpace diskCacheDirectory:(NSString *)directory fileHeader:(nullable NSString*)fileHeader {
    return [self initWithNamespace:nameSpace diskCacheDirectory:directory storagePolicy:MXStoragePolicyYYYYMMDD fileName:nil fileHeader:fileHeader cryptKey:nil iv:nil];
}

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder {
    return [self initWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:MXStoragePolicyYYYYMMDD fileName:nil fileHeader:fileHeder cryptKey:nil iv:nil];
}
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder {
    return [self initWithNamespace:nameSpace diskCacheDirectory:nil storagePolicy:storagePolicy fileName:fileName fileHeader:fileHeder cryptKey:nil iv:nil];
}
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv{
    if (self = [super init]) {
        if (!directory) {
            directory = [MXLogger defaultDiskCacheDirectory];
        }
        _nameSpace = nameSpace;
        _directory = directory;
        const char * storage_policy = "yyyy_MM_dd";
        switch (storagePolicy) {
            case MXStoragePolicyYYYYMMDD:
                storage_policy = "yyyy_MM_dd";
                break;
            case MXStoragePolicyYYYYMMDDHH:
                storage_policy = "yyyy_MM_dd_HH";
                break;
            case MXStoragePolicyYYYYWW:
                storage_policy = "yyyy_ww";
                break;
            case  MXStoragePolicyYYYYMM:
                storage_policy = "yyyy_MM";
                break;
        }
        
        const char * file_name = [self isNull:fileName] ? nullptr : fileName.UTF8String;
        
        const char * crypt_key = [self isNull:cryptKey] ? nullptr : cryptKey.UTF8String;
        const char * iv_ = [self isNull:iv] ? nullptr : iv.UTF8String;
        
        const char * file_heder = [self isNull:fileHeder] ? nullptr : fileHeder.UTF8String;
        
        _logger =  mx_logger::initialize_namespace(nameSpace.UTF8String, directory.UTF8String,storage_policy,file_name,file_heder,crypt_key,iv_);
        
        self.loggerKey = [NSString stringWithUTF8String:_logger->logger_key()];
        

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterrForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
   
        _shouldRemoveExpiredDataWhenEnterBackground = YES;
      
       
        [global_instanceDic setObject:self forKey:self.loggerKey];
        
    }
    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    mx_logger::delete_namespace(_nameSpace.UTF8String, _directory.UTF8String);
    
}

-(void)applicationDidEnterrForeground:(NSNotification *)notification{

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
 
    [self removeExpireData];
    [application endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
}



-(void)setEnable:(BOOL)enable{
    _enable = enable;
    _logger -> set_enable(enable);
}
-(void)setConsoleEnable:(BOOL)consoleEnable{
    _consoleEnable = consoleEnable;
    _logger -> set_enable_console(consoleEnable);
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

-(void)removeBeforeAllData{
    _logger -> remove_before_all();
}
-(void)removeAllData{
    _logger -> remove_all();
}

- (NSUInteger)logSize{
   long size =  _logger -> dir_size();
    return [[NSNumber numberWithLong:size] unsignedIntegerValue];
}
-(void)setLevel:(NSInteger)level{
    _level = level;
    _logger -> set_log_level([NSNumber numberWithInteger:level].intValue);
}



-(NSInteger)debugWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    return  [self logWithLevel:0 name:name msg:msg tag:tag];
}
-(NSInteger)infoWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    return [self logWithLevel:1 name:name msg:msg tag:tag];
}

-(NSInteger)warnWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    return [self logWithLevel:2 name:name msg:msg tag:tag];
}

-(NSInteger)errorWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    return [self logWithLevel:3 name:name msg:msg tag:tag];
}

-(NSInteger)fatalWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    return [self logWithLevel:4 name:name msg:msg tag:tag];
}

-(NSInteger)logWithLevel:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag {
    return  [self innerLogWithLevel:level name:name msg:msg tag:tag];
}

-(NSInteger)innerLogWithLevel:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag {
    BOOL isMainThread = [NSThread isMainThread];
  
    int level_ = [NSNumber numberWithInteger:level].intValue;
   
    const char* name_ = [self isNull:name] == YES ? nullptr : name.UTF8String;
    const char* tag_ = [self isNull:tag] == YES ? nullptr : tag.UTF8String;
    const char* msg_ = [self isNull:msg] == YES ? nullptr : msg.UTF8String;
    
    int result =  _logger -> log(level_,name_, msg_, tag_, isMainThread);
    return result;
}

-(BOOL)isNull:(NSString*) object{
    if (object == NULL || object == nullptr) {
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



+(NSInteger)debugWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
  
    return  [logger debugWithName:name msg:msg tag:tag];
}

+(NSInteger)infoWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
  
    return  [logger infoWithName:name msg:msg tag:tag];
}


+(NSInteger)warnWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
  
    return [logger warnWithName:name msg:msg tag:tag];
}

+(NSInteger)errorWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
  
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
  
    return [logger errorWithName:name msg:msg tag:tag];
}

+(NSInteger)fatalWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag{
    
    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
  
    return  [logger fatalWithName:name msg:msg tag:tag];
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

+(NSArray<NSDictionary*>*)selectWithDiskCacheFilePath:(nonnull NSString*)diskCacheFilePath cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv{

  
  
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::util::mxlogger_util::select_log_form_path(diskCacheFilePath.UTF8String, &destination,cryptKey.UTF8String,iv.UTF8String);
    
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
        std::string thread_id = log_map["thread_id"];
        std::string error_code = log_map["error_code"];
        
        NSDictionary * dictionary = @{
            @"msg":[NSString stringWithUTF8String:msg.data()],
            @"name":[NSString stringWithUTF8String:name.data()],
            @"tag":[NSString stringWithUTF8String:tag.data()],
            @"is_main_thread":[NSString stringWithUTF8String:is_main_thread.data()],
            @"thread_id":[NSString stringWithUTF8String:thread_id.data()],
            @"timestamp":[NSString stringWithUTF8String:timestamp.data()],
            @"level":[NSString stringWithUTF8String:level.data()],
            @"error_code":[NSString stringWithUTF8String:error_code.data()]
            
        };
        
        [messageList addObject:dictionary];
    }

    return [messageList copy];
   
}

-(NSArray<NSDictionary<NSString*,NSString*>*>*)logFiles{
   
    std::vector<std::map<std::string, std::string>> destination;
    
    
    mxlogger::util::mxlogger_util::select_logfiles_dir(self.diskCachePath.UTF8String, &destination);
    
    NSMutableArray<NSDictionary<NSString*,NSString*>*>* files = [NSMutableArray arrayWithCapacity:destination.size()];
    
    for (int i = 0; i< destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        NSString * name = [NSString stringWithUTF8String:map["name"].data()];
        NSString * size = [NSString stringWithUTF8String:map["size"].data()];
        NSString * last_timestamp = [NSString stringWithUTF8String:map["last_timestamp"].data()];
        
        NSString * create_timestamp  =  [NSString stringWithUTF8String:map["create_timestamp"].data()];
        
        NSDictionary *dictionary = @{@"name":name,@"size":size,@"last_timestamp":last_timestamp,@"create_timestamp":create_timestamp};
        
        [files addObject:dictionary];
    }
  
    
    return [files copy];
}

+(NSString*)mapKey:(NSString*)nameSpace diskCacheDirectory:(NSString*)directory{
    
    if (!directory) {
        directory = [MXLogger defaultDiskCacheDirectory];
    }
    std::string mapKey =  mx_logger::md5(nameSpace.UTF8String, directory.UTF8String);
    
    NSString * key =  [NSString stringWithUTF8String:mapKey.data()];
    return key;
}

@end
