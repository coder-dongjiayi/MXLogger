//
//  MXLogger.h
//  Logger
//
//  Created by 董家祎 on 2022/3/1.
//



#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN


@interface MXLogger : NSObject


/// 创建对象
/// @param nameSpace ns  要调用  destroyWithNamespace 进行释放
+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory  storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName;

+(instancetype)initializeWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;



/// 释放对象的方法
/// @param nameSpace ns
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace;
+(void)destroyWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory;




/// 默认路径初始化
/// @param nameSpace 默认在 Library目录下

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace;


/// 初始化MXLogger
/// @param nameSpace 命名空间
/// @param directory 目录
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory;


/// 加密初始化

-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;


-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName;

/// 初始化方法
/// @param nameSpace nameSpace
/// @param directory directory
/// @param storagePolicy
/// ///  文件存储策略
///  yyyy_MM                    按月存储
///  yyyy_MM_dd              按天存储
///  yyyy_ww                     按周存储
///  yyyy_MM_dd_HH       按小时存储
 /// 以上是文件的命名策略
/// @param fileName fileName
/// cryptKey 16字节 大于16字节自动裁掉 小于16字节填充0
/// iv 默认和key一样
-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory storagePolicy:(nullable NSString*)storagePolicy fileName:(nullable NSString*) fileName cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;

/// 程序结束的时候是否清理过期文件 默认YES
@property(nonatomic,assign)BOOL shouldRemoveExpiredDataWhenTerminate;

/// 程序进入后台的时候是否清理过期文件 默认YES
@property(nonatomic,assign)BOOL shouldRemoveExpiredDataWhenEnterBackground;

/// 是否开启控制台打印，默认不开启
@property (nonatomic,assign)BOOL consoleEnable;

/// 禁用日志
@property (nonatomic,assign)BOOL enable;

/// 是否开启调试日志
@property (nonatomic,assign)BOOL debug;

/// 日志文件磁盘缓存目录
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;

/// 日志文件最大字节数 默认0 无限制
@property (nonatomic,assign)NSUInteger maxDiskSize;

/// 日志文件存储最长时间 默认0 无限制
@property (nonatomic,assign)NSUInteger maxDiskAge;

/// 日志文件大小
@property (nonatomic,assign,readonly)NSUInteger logSize;


/// 设置写入文件日志等级
@property (nonatomic,assign)NSInteger level;



+(NSArray<NSDictionary*>*)selectWithDiskCacheFilePath:(nonnull NSString*)diskCacheFilePath cryptKey:(nullable NSString*)cryptKey iv:(nullable NSString*)iv;

+(NSArray<NSDictionary<NSString*,NSString*>*>*)selectLogfilesWithDirectory:(nonnull NSString*)directory;

/// 清理过期文件
-(void)removeExpireData;

/// 清理全部日志文件
-(void)removeAllData;


/// 输出日志
/// @param level 等级
/// @param name name
/// @param tag tag
/// @param msg msg
-(void)log:(NSInteger)level name:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;


-(void)debug:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)info:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)warn:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)error:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;

-(void)fatal:(nullable NSString*)name msg:(nonnull NSString*)msg tag:(nullable NSString*)tag;



@end

NS_ASSUME_NONNULL_END
