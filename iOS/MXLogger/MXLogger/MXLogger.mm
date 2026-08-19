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

/// 失效实例：移除通知监听并清空_logger，destroy后残留的实例调用任何方法都会安全短路
/// Invalidate the instance: remove notification observers and clear _logger so that
/// any call on an instance kept around after destroy short-circuits safely
- (void)mx_invalidate;

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

    MXLogger * logger = [global_instanceDic objectForKey:loggerKey];
    if (logger != nil) {
        /// 先失效实例再销毁C++对象：业务可能仍持有这个OC实例，
        /// 置空_logger后后续调用会安全短路而不是使用已释放的指针
        /// Invalidate the instance before destroying the C++ object: the business layer
        /// may still hold this OC instance, and a cleared _logger makes later calls
        /// short-circuit safely instead of touching freed memory
        [logger mx_invalidate];
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
        /// 同一nameSpace+directory已存在实例时直接复用：底层C++对象本来就是同一个，
        /// 如果创建第二个OC实例，它会把字典里的旧实例顶掉，旧实例dealloc时
        /// delete_namespace会删掉两个实例共享的C++对象，新实例的_logger随即悬垂
        /// Reuse the existing instance for the same nameSpace + directory: the underlying
        /// C++ object is shared anyway. A second OC instance would evict the old one from
        /// the dictionary; when the old one deallocs, delete_namespace destroys the shared
        /// C++ object and leaves the new instance's _logger dangling
        if (global_instanceDic == nil) {
            global_instanceDic = [NSMutableDictionary dictionary];
        }
        NSString * existKey = [MXLogger mapKey:nameSpace diskCacheDirectory:directory];
        MXLogger * exist = [global_instanceDic objectForKey:existKey];
        if (exist != nil) {
            return exist;
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


- (void)mx_invalidate
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _logger = nullptr;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    /// 实例只会在destroyWithLoggerKey移除字典强引用后走到这里，
    /// 显式destroy的路径中C++对象已被删除，此调用查不到key时是安全的无操作
    /// An instance only deallocs after destroyWithLoggerKey drops the dictionary's
    /// strong reference; when the C++ object was already destroyed there, this call
    /// finds no key and is a safe no-op
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



/// 以下方法统一判空_logger：实例被destroy失效后调用安全短路
/// All methods below check _logger: calls after destroy short-circuit safely
-(void)setEnable:(BOOL)enable{
    if (_logger == nullptr) return;
    _enable = enable;
    _logger -> set_enable(enable);
}
-(void)setConsoleEnable:(BOOL)consoleEnable{
    if (_logger == nullptr) return;
    _consoleEnable = consoleEnable;
    _logger -> set_enable_console(consoleEnable);
}


-(void)setMaxDiskAge:(NSUInteger)maxDiskAge{
    if (_logger == nullptr) return;
    _maxDiskAge = maxDiskAge;

    _logger -> set_file_max_age([NSNumber numberWithUnsignedInteger:maxDiskAge].longValue);

}
- (void)setMaxDiskSize:(NSUInteger)maxDiskSize{
    if (_logger == nullptr) return;
    _maxDiskSize = maxDiskSize;

    _logger -> set_file_max_size([NSNumber numberWithUnsignedInteger:maxDiskSize].longValue);
}

-(void)removeExpireData{
    if (_logger == nullptr) return;
    _logger -> remove_expire_data();
}

-(void)removeBeforeAllData{
    if (_logger == nullptr) return;
    _logger -> remove_before_all();
}
-(void)removeAllData{
    if (_logger == nullptr) return;
    _logger -> remove_all();
}

- (NSUInteger)logSize{
    if (_logger == nullptr) return 0;
   long size =  _logger -> dir_size();
    return [[NSNumber numberWithLong:size] unsignedIntegerValue];
}
-(void)setLevel:(NSInteger)level{
    if (_logger == nullptr) return;
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
    if (_logger == nullptr) return 0;
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
    if (_logger == nullptr) return @"";
    return [NSString stringWithUTF8String:_logger->diskcache_path()];
}

-(NSString*)errorDesc{
    if (_logger == nullptr) return @"";
    return   [NSString stringWithUTF8String:_logger->error_desc()];
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

/// 安全转换：stringWithUTF8String对非法UTF-8返回nil，直接塞进字典字面量会抛
/// NSInvalidArgumentException（文件半损坏但通过flatbuffers校验时可能出现），兜底为空串
/// Safe conversion: stringWithUTF8String returns nil for invalid UTF-8, and a nil value
/// in a dictionary literal throws NSInvalidArgumentException (possible when a file is
/// partially corrupted yet passes the flatbuffers verifier); fall back to an empty string
static NSString * mx_safe_string_(const std::string &str){
    NSString * result = [NSString stringWithUTF8String:str.c_str()];
    return result == nil ? @"" : result;
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
            @"msg":mx_safe_string_(msg),
            @"name":mx_safe_string_(name),
            @"tag":mx_safe_string_(tag),
            @"is_main_thread":mx_safe_string_(is_main_thread),
            @"thread_id":mx_safe_string_(thread_id),
            @"timestamp":mx_safe_string_(timestamp),
            @"level":mx_safe_string_(level),
            @"error_code":mx_safe_string_(error_code)

        };

        [messageList addObject:dictionary];
    }

    return [messageList copy];

}

-(NSArray<NSDictionary<NSString*,NSString*>*>*)logFiles{
    if (_logger == nullptr) return @[];

    std::vector<std::map<std::string, std::string>> destination;


    mxlogger::util::mxlogger_util::select_logfiles_dir(self.diskCachePath.UTF8String, &destination);

    NSMutableArray<NSDictionary<NSString*,NSString*>*>* files = [NSMutableArray arrayWithCapacity:destination.size()];

    for (int i = 0; i< destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        NSString * name = mx_safe_string_(map["name"]);
        NSString * size = mx_safe_string_(map["size"]);
        NSString * last_timestamp = mx_safe_string_(map["last_timestamp"]);

        NSString * create_timestamp  =  mx_safe_string_(map["create_timestamp"]);

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
