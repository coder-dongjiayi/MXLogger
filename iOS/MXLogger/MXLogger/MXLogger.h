//
//  MXLogger.h
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
//日志文件存储策略
typedef NS_ENUM(NSInteger, MXStoragePolicyType) {
    MXStoragePolicyYYYYMMDD = 0, // 按天存储 对应文件名: 2023-01-11_filename.mx
    MXStoragePolicyYYYYMMDDHH,  // 按小时存储 对应文件名: 2023-01-11-15_filename.mx
    MXStoragePolicyYYYYWW,     // 按周存储 对应文件名: 2023-01-02w_filename.mx（02w是指一年中的第2周）
    MXStoragePolicyYYYYMM,    // 按月存储 对应文件名: 2023-01_filename.mx
};

@interface MXLogger : NSObject

/// 创建对象
/// @param nameSpace ns  要调用  destroyWithNamespace 进行释放

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory  storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName  fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;


/// 释放对象的方法

///通过  loggerKey 释放
+(void)destroyWithLoggerKey:(nonnull NSString*)loggerKey;
/// @param nameSpace ns
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace;

+(void)destroyWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory;



/// 默认路径初始化
/// @param nameSpace 默认在 Library目录下

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace fileHeader:(nullable NSString*)fileHeder;


/// 初始化MXLogger
/// @param nameSpace 命名空间
/// @param directory 目录
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory fileHeader:(nullable NSString*)fileHeder ;


/// 加密初始化
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv fileHeader:(nullable NSString*)fileHeder;


-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder;

/// 初始化方法
/// @param nameSpace nameSpace
/// @param directory directory
/// @param storagePolicy 文件存储策略 默认值MXStoragePolicyYYYYMMDD 按天存
/// @param fileName fileName 默认log
/// @param cryptKey 16字节 大于16字节自动裁掉 小于16字节填充0
/// iv 默认和key一样
/// @param fileHeder 日志文件头信息，业务可以在初始化mxlogger的时候 写入一些业务相关的信息 比如app版本 所属平台等等 文件创建的时候这条数据会被写入
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory storagePolicy:(MXStoragePolicyType)storagePolicy fileName:(nullable NSString*) fileName fileHeader:(nullable NSString*)fileHeder cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;


/// 程序进入后台的时候是否清理过期文件 默认YES
@property(nonatomic,assign)BOOL shouldRemoveExpiredDataWhenEnterBackground;

/// 是否开启控制台打印，默认不开启, 开启控制台打印会影响 写入效率 ，建议发布模式禁用 consoleEnable
/// 如果要做性能测试 要设置 consoleEnable = NO;
@property (nonatomic,assign)BOOL consoleEnable;

/// 禁用日志
@property (nonatomic,assign)BOOL enable;

/// 日志文件磁盘缓存目录
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;

/// 日志文件最大字节数 默认0 无限制
@property (nonatomic,assign)NSUInteger maxDiskSize;

/// 日志文件存储最长时间 默认0 无限制
@property (nonatomic,assign)NSUInteger maxDiskAge;

/// 日志文件大小
@property (nonatomic,assign,readonly)NSUInteger logSize;


/// 设置写入文件的日志等级
///  0:debug 1:info 2:warn 3:error 4:fatal
///  比如 level = 1 那么小于1等级的日志 将不会被写入文件(如果设置了consoleEnable=YES,只会输出到控制台) 以此类推。
///  如果开启了consoleEnable = YES ,控制台会输出所有的日志，这个字段只针对磁盘文件写入有效
@property (nonatomic,assign)NSInteger level;

/// nameSpace+diskCacheDirectory 做一次md5的值，对应一个logger对象，可以通过这个操作logger对象。
 /// 业务场景: 如果是一个大型的app 你的app可能会模块化(组件化)
 /// 但是你希望所有子模块(子组件)使用在主工程初始化的log，
 /// 这个时候为了方便解耦业务你不需要传logger对象 只需要传入这个key，然后通过logLoggerKey 进行日志写入
@property (nonatomic,copy,nonnull,readonly)NSString* loggerKey;

+(NSArray<NSDictionary*>*)selectWithDiskCacheFilePath:(nonnull NSString*)diskCacheFilePath cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;


///获取存储的日志文件信息
/*
 [
  {
    "name":"文件名",
    "size":"文件大小(字节)",
    "last_timestamp":"文件最后更新时间",
    "create_timestamp":"文件创建时间"
   }
 ]
 */

-(NSArray<NSDictionary<NSString*,NSString*>*>*)logFiles;


/// 通过mapKey  返回logger对象，如果不存在返回null
+(MXLogger*)valueForLoggerKey:(NSString*)loggerKey;

/// 清理过期文件
-(void)removeExpireData;

/// 清理全部日志文件
-(void)removeAllData;

// 删除除当前正在写入日志文件外的所有日志文件
-(void)removeBeforeAllData;

/// 输出日志
/// @param level 等级
/// @param name name
/// @param tag tag
/// @param msg msg
-(void)logWithLevel:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;


-(void)debugWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)infoWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)warnWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)errorWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)fatalWithName:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;


// 类方法 使用已存在的loggerKey写入日志

+(void)debugWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

+(void)infoWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

+(void)warnWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

+(void)errorWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

+(void)fatalWithLoggerKey:(nonnull NSString*)loggerKey name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;


@end

NS_ASSUME_NONNULL_END
