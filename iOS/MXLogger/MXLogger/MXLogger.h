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


-(instancetype)initWithNamespace:(nonnull NSString*)nameSpace diskCacheDirectory:(nullable NSString*) directory;


/// 禁用日志
@property (nonatomic,assign)BOOL enable;

/// 禁用/开启 控制台输出
@property (nonatomic,assign)BOOL consoleEnable;


/// 禁用/开启 文件写入
@property (nonatomic,assign)BOOL fileEnable;

///  文件存储策略
///  yyyy_MM                    按月存储
///  yyyy_MM_dd              按天存储
///  yyyy_ww                     按周存储
///  yyyy_MM_dd_HH       按小时存储
@property (nonatomic,copy)NSString * storagePolicy;


/// 每次创建一个新的日志文件 写入文件头的信息
@property (nonatomic,copy)NSString * fileHeader;

/// 自定义日志文件名 默认值:mxlog

@property (nonatomic,copy)NSString *fileName;


/// 日志文件磁盘缓存目录
@property (nonatomic, copy, nonnull, readonly) NSString *diskCachePath;


/// 输出日志
/// @param level 等级
/// @param name name
/// @param tag tag
/// @param msg msg
-(void)log:(NSInteger)level name:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

-(void)info:(NSString*)name msg:(NSString*)msg tag:(NSString*)tag;

@end

NS_ASSUME_NONNULL_END
