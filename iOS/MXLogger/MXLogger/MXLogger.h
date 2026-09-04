//
//  MXLogger.h
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

/// Swift 调用名通过 NS_SWIFT_NAME 单独指定(见各声明尾部)，Objective-C 接口名与行为均未改变:
///   MXLogger.shared(namespace:) / destroy(namespace:) / logger(forKey:) / select(filePath:cryptKey:iv:)
///   logger.info(name:message:tag:) / logger.isEnabled / logger.isConsoleEnabled
/// Swift names are assigned separately via NS_SWIFT_NAME (see the end of each declaration);
/// the Objective-C selectors and behavior are unchanged:
///   MXLogger.shared(namespace:) / destroy(namespace:) / logger(forKey:) / select(filePath:cryptKey:iv:)
///   logger.info(name:message:tag:) / logger.isEnabled / logger.isConsoleEnabled

/// 日志文件存储策略
/// Log file storage policy
@class MXLogger;

/// Swift 侧导入为 MXLogger.StoragePolicy，case 为 .daily/.hourly/.weekly/.monthly
/// Imported into Swift as MXLogger.StoragePolicy with cases .daily/.hourly/.weekly/.monthly
typedef NS_ENUM(NSInteger, MXStoragePolicyType) {
    /// 按天存储，对应文件名: 2023-01-11_filename.mx
    /// One file per day, e.g. 2023-01-11_filename.mx
    MXStoragePolicyYYYYMMDD NS_SWIFT_NAME(daily) = 0,
    /// 按小时存储，对应文件名: 2023-01-11-15_filename.mx
    /// One file per hour, e.g. 2023-01-11-15_filename.mx
    MXStoragePolicyYYYYMMDDHH NS_SWIFT_NAME(hourly),
    /// 按周存储，对应文件名: 2023-01-02w_filename.mx（02w 是指一年中的第 2 周）
    /// One file per week, e.g. 2023-01-02w_filename.mx (02w means the 2nd week of the year)
    MXStoragePolicyYYYYWW NS_SWIFT_NAME(weekly),
    /// 按月存储，对应文件名: 2023-01_filename.mx
    /// One file per month, e.g. 2023-01_filename.mx
    MXStoragePolicyYYYYMM NS_SWIFT_NAME(monthly),
} NS_SWIFT_NAME(MXLogger.StoragePolicy);

@interface MXLogger : NSObject

/// 创建（或获取）logger 对象：同一 nameSpace 只会创建一个实例，使用默认目录
/// Library/com.mxlog.LoggerCache，需调用 destroyWithNamespace 释放
/// Create (or fetch) a logger instance: only one instance is created per nameSpace, stored in
/// the default directory Library/com.mxlog.LoggerCache; call destroyWithNamespace to release it
/// @param nameSpace 命名空间 / namespace
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace NS_SWIFT_NAME(shared(namespace:));

/// 创建（或获取）logger 对象，并指定日志文件头信息
/// Create (or fetch) a logger instance with a custom file header
/// @param nameSpace 命名空间 / namespace
/// @param fileHeder 日志文件头信息，文件创建时写入 / file header written when the log file is created
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder NS_SWIFT_NAME(shared(namespace:fileHeader:));

/// 创建（或获取）加密的 logger 对象
/// Create (or fetch) an encrypted logger instance
/// @param nameSpace 命名空间 / namespace
/// @param cryptKey AES-CFB 加密 key / AES-CFB encryption key
/// @param iv 加密向量，为空时默认与 key 相同 / initialization vector, defaults to the key when nil
/// @param fileHeder 日志文件头信息 / file header
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder NS_SWIFT_NAME(shared(namespace:cryptKey:iv:fileHeader:));

/// 创建（或获取）logger 对象（完整参数版本）
/// Create (or fetch) a logger instance (full-parameter version)
/// @param nameSpace 命名空间 / namespace
/// @param directory 磁盘缓存目录，为空时默认 Library/com.mxlog.LoggerCache
///                  / disk-cache directory, defaults to Library/com.mxlog.LoggerCache when nil
/// @param storagePolicy 文件存储策略 / file storage policy
/// @param fileName 日志文件名，为空时默认 mxlog / log file name, defaults to "mxlog" when nil
/// @param fileHeder 日志文件头信息 / file header
/// @param cryptKey AES-CFB-128 加密 key，为空时不加密；16 字节：大于 16 字节自动裁掉，小于 16 字节填充 0
///                 / AES-CFB-128 encryption key, no encryption when nil;
///                 16 bytes: truncated if longer, zero-padded if shorter
/// @param iv 加密向量，为空时默认与 key 相同 / initialization vector, defaults to the key when nil
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory  storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName  fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv NS_SWIFT_NAME(shared(namespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:));

/// 创建（或获取）logger 对象，并指定存储策略和文件名（不加密）
/// Create (or fetch) a logger instance with a storage policy and file name (no encryption)
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder NS_SWIFT_NAME(shared(namespace:storagePolicy:fileName:fileHeader:));

/// 创建（或获取）logger 对象，并指定存储策略、文件名和加密信息
/// Create (or fetch) a logger instance with a storage policy, file name and encryption settings
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv NS_SWIFT_NAME(shared(namespace:storagePolicy:fileName:fileHeader:cryptKey:iv:));


/// 通过 loggerKey 释放 logger 对象
/// Release the logger identified by loggerKey
+(void)destroyWithLoggerKey:(nonnull NSString*)loggerKey NS_SWIFT_NAME(destroy(loggerKey:));

/// 通过 nameSpace 释放 logger 对象（使用默认目录）
/// Release the logger identified by nameSpace (with the default directory)
/// @param nameSpace 命名空间 / namespace
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace NS_SWIFT_NAME(destroy(namespace:));

/// 通过 nameSpace + 磁盘缓存目录 释放 logger 对象
/// Release the logger identified by nameSpace + disk-cache directory
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory NS_SWIFT_NAME(destroy(namespace:diskCacheDirectory:));



/// 默认路径初始化：日志存储在 Library/com.mxlog.LoggerCache 目录下
/// Initialize with the default path: logs are stored under Library/com.mxlog.LoggerCache
/// @param nameSpace 命名空间 / namespace
/// @param fileHeder 日志文件头信息 / file header
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder;


/// 指定目录初始化
/// Initialize with a custom directory
/// @param nameSpace 命名空间 / namespace
/// @param directory 磁盘缓存目录 / disk-cache directory
/// @param fileHeder 日志文件头信息 / file header
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory fileHeader:(nullable NSString*)fileHeder ;


/// 加密初始化：日志内容使用 AES-CFB 加密写入
/// Initialize with encryption: log content is written with AES-CFB encryption
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder;


/// 指定存储策略和文件名初始化（不加密）
/// Initialize with a storage policy and file name (no encryption)
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder;

/// 完整初始化方法（其他初始化方法最终都会调用它）
/// Designated initializer (all other initializers funnel into this one)
/// @param nameSpace 命名空间 / namespace
/// @param directory 磁盘缓存目录，为空时默认 Library/com.mxlog.LoggerCache
///                  / disk-cache directory, defaults to Library/com.mxlog.LoggerCache when nil
/// @param storagePolicy 文件存储策略，默认 MXStoragePolicyYYYYMMDD 按天存储 / storage policy, defaults to MXStoragePolicyYYYYMMDD (daily)
/// @param fileName 文件名，默认 mxlog / file name, defaults to "mxlog"
/// @param fileHeder 日志文件头信息，业务可以在初始化时写入一些业务相关的信息（如 app 版本、所属平台等），文件创建时这条数据会被写入
///                  file header; the business layer can write context info (app version, platform, etc.),
///                  written once when the file is created
/// @param cryptKey 加密 key，16 字节：大于 16 字节自动裁掉，小于 16 字节填充 0
///                 encryption key, 16 bytes: truncated if longer, zero-padded if shorter
/// @param iv 加密向量，默认和 key 一样 / initialization vector, defaults to the key
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;


/// 程序进入后台的时候是否清理过期文件，默认 YES
/// Whether to remove expired log files when the app enters background, defaults to YES
@property(nonatomic,assign)BOOL shouldRemoveExpiredDataWhenEnterBackground;

/// 是否开启控制台打印，默认不开启。开启控制台打印会影响写入效率；
/// 如果要做性能测试，要设置 consoleEnable = NO。
/// Release/Profile 构建下控制台输出已在编译期整段裁掉(连判断都不会执行)，此时设为 YES 也不会
/// 有任何输出；确实需要在 Release 包里看日志(灰度/QA包)，在宿主 target 的
/// GCC_PREPROCESSOR_DEFINITIONS 里加 MXLOGGER_CONSOLE_ENABLED=1 覆盖。
/// Whether to print logs to the console, disabled by default. Console output hurts write
/// performance — set consoleEnable = NO for benchmarks.
/// In Release/Profile builds the console path is stripped at compile time (not even the
/// check runs), so setting YES prints nothing. To keep it in a Release build (QA/beta),
/// define MXLOGGER_CONSOLE_ENABLED=1 in the host target's GCC_PREPROCESSOR_DEFINITIONS.
@property (nonatomic,assign)BOOL consoleEnable NS_SWIFT_NAME(isConsoleEnabled);

/// 是否启用日志写入，设为 NO 时禁用日志
/// Whether logging is enabled; set to NO to disable logging
@property (nonatomic,assign)BOOL enable NS_SWIFT_NAME(isEnabled);

/// 日志文件磁盘缓存目录
/// Disk-cache directory of the log files
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;

/// 日志文件最大字节数，默认 0 无限制；超限清理在 removeExpireData 时执行
/// Maximum total size of log files in bytes, defaults to 0 (unlimited);
/// the over-limit cleanup runs when removeExpireData is called
@property (nonatomic,assign)NSUInteger maxDiskSize;

/// 日志文件最大存储时长(秒)，默认 0 无限制；以文件最后修改时间判断是否过期
/// Maximum age of log files in seconds, defaults to 0 (unlimited);
/// expiry is judged by each file's last-modified time
@property (nonatomic,assign)NSUInteger maxDiskAge;

/// 当前日志目录占用的磁盘大小(字节)
/// Current disk size occupied by the log directory in bytes
@property (nonatomic,assign,readonly)NSUInteger logSize;


/// 设置写入文件的日志等级：0:debug 1:info 2:warn 3:error 4:fatal。
/// 比如 level = 1，那么小于 1 等级的日志将不会被写入文件（如果设置了 consoleEnable=YES，只会输出到控制台），以此类推；
/// 如果开启了 consoleEnable = YES，控制台会输出所有的日志，这个字段只针对磁盘文件写入有效
/// Minimum level written to disk: 0 debug, 1 info, 2 warn, 3 error, 4 fatal.
/// E.g. level = 1 means logs below level 1 are not written to file (they still go to the console
/// when consoleEnable = YES). This field only affects disk writes — with consoleEnable = YES the
/// console always prints every log
@property (nonatomic,assign)NSInteger level;

/// nameSpace + diskCacheDirectory 做一次 md5 的值，唯一对应一个 logger 对象，可以通过它操作 logger。
/// 业务场景：如果是一个大型的 app，你的 app 可能会模块化（组件化），但是你希望所有子模块（子组件）使用在主工程初始化的 log，
/// 这个时候为了方便解耦业务你不需要传 logger 对象，只需要传入这个 key，然后通过 xxxWithLoggerKey 进行日志写入
/// The md5 of nameSpace + diskCacheDirectory, uniquely identifying this logger instance.
/// Use case: in a large modularized app, sub-modules can share the logger initialized in the main
/// project by passing this key around (instead of the logger object) and writing logs via the
/// xxxWithLoggerKey class methods — keeping modules decoupled
@property (nonatomic,copy,nonnull,readonly)NSString* loggerKey;

/// 解析指定路径的日志文件，返回日志条目列表（按时间倒序）；加密文件需传入对应的 cryptKey 和 iv
/// Parse the log file at the given path and return its entries (newest first); pass the matching
/// cryptKey and iv for encrypted files
/// @param diskCacheFilePath 日志文件完整路径 / full path of the log file
/// @param cryptKey 加密 key，未加密文件传 nil / encryption key, nil for unencrypted files
/// @param iv 加密向量 / initialization vector
+(NSArray<NSDictionary*>*)selectWithDiskCacheFilePath:(nonnull NSString*)diskCacheFilePath cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv NS_SWIFT_NAME(select(filePath:cryptKey:iv:));


/// 获取存储的日志文件信息
/// Get the metadata of all stored log files
/*
 [
  {
    "name":"文件名 / file name",
    "size":"文件大小(字节) / file size in bytes",
    "last_timestamp":"文件最后更新时间 / last-modified timestamp",
    "create_timestamp":"文件创建时间 / creation timestamp"
   }
 ]
 */
-(NSArray<NSDictionary<NSString*,NSString*>*>*)logFiles;


/// 返回最近一次写入失败的错误信息
/// Return the description of the most recent write error
-(NSString*)errorDesc;

/// 通过 loggerKey 返回已存在的 logger 对象，如果不存在返回 nil
/// Return the existing logger instance for the given loggerKey, or nil if none exists
+(MXLogger*)valueForLoggerKey:(NSString*)loggerKey NS_SWIFT_NAME(logger(forKey:));

/// 清理日志文件：先删除过期文件（最后修改时间超过 maxDiskAge），若总大小仍超过 maxDiskSize
/// 则从最旧的文件开始继续删除；当前正在写入的文件不会被删除。
/// 程序进入后台时默认会自动调用（见 shouldRemoveExpiredDataWhenEnterBackground）
/// Clean up log files: first delete expired files (last-modified time older than maxDiskAge),
/// then, if the total size still exceeds maxDiskSize, keep deleting from the oldest file onward;
/// the file currently being written is never deleted.
/// Called automatically when the app enters background by default
/// (see shouldRemoveExpiredDataWhenEnterBackground)
-(void)removeExpireData;

/// 清理全部日志文件
/// Remove all log files
-(void)removeAllData;

/// 删除除当前正在写入日志文件外的所有日志文件
/// Remove all log files except the one currently being written
-(void)removeBeforeAllData;

/// 输出日志
/// Write a log entry
/// @return 0 成功（-1 扩容失败 -2 解除映射失败 -3 映射失败，调用 errorDesc 方法查看错误信息）
///         0 success (-1 file expansion failed, -2 unmap failed, -3 mmap failed; call errorDesc for details)
/// @param level 日志等级：0 debug 1 info 2 warn 3 error 4 fatal / log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
/// @param name 日志名称 / logger name
/// @param msg 日志信息 / log message
/// @param tag 标记 / tag
-(NSInteger)logWithLevel:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(log(level:name:message:tag:));


/// 输出 debug 等级日志
/// Write a debug-level log entry
-(NSInteger)debugWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(debug(name:message:tag:));

/// 输出 info 等级日志
/// Write an info-level log entry
-(NSInteger)infoWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(info(name:message:tag:));

/// 输出 warn 等级日志
/// Write a warn-level log entry
-(NSInteger)warnWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(warn(name:message:tag:));

/// 输出 error 等级日志
/// Write an error-level log entry
-(NSInteger)errorWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(error(name:message:tag:));

/// 输出 fatal 等级日志
/// Write a fatal-level log entry
-(NSInteger)fatalWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(fatal(name:message:tag:));


// 类方法：使用已存在的 loggerKey 写入日志（适用于模块化场景，无需持有 logger 对象）
// Class methods: write logs via an existing loggerKey (for modularized apps, no logger instance needed)

/// 通过 loggerKey 输出 debug 等级日志
/// Write a debug-level log entry via loggerKey
+(NSInteger)debugWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(debug(loggerKey:name:message:tag:));

/// 通过 loggerKey 输出 info 等级日志
/// Write an info-level log entry via loggerKey
+(NSInteger)infoWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(info(loggerKey:name:message:tag:));

/// 通过 loggerKey 输出 warn 等级日志
/// Write a warn-level log entry via loggerKey
+(NSInteger)warnWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(warn(loggerKey:name:message:tag:));

/// 通过 loggerKey 输出 error 等级日志
/// Write an error-level log entry via loggerKey
+(NSInteger)errorWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(error(loggerKey:name:message:tag:));

/// 通过 loggerKey 输出 fatal 等级日志
/// Write a fatal-level log entry via loggerKey
+(NSInteger)fatalWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag NS_SWIFT_NAME(fatal(loggerKey:name:message:tag:));


@end

NS_ASSUME_NONNULL_END
