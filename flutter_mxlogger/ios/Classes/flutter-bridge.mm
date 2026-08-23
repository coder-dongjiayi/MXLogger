//
//  flutter-bridge.m
//  Logger
//
//  Created by 董家祎 on 2022/3/11.
//
//  Flutter FFI桥接层(iOS): 以C符号(flutter_mxlogger_前缀)导出OC版MXLogger的能力，
//  供Dart侧通过dart:ffi的lookup绑定调用，与Android端flutter-bridge.cpp的导出符号对应
//  (iOS额外多导出一个select_logfiles占位符号)
//  Flutter FFI bridge (iOS): exports the Objective-C MXLogger as C symbols (prefixed
//  with flutter_mxlogger_) so the Dart side can bind them via dart:ffi lookup;
//  symbols correspond to the Android flutter-bridge.cpp exports
//  (iOS additionally exports a select_logfiles stub)
//

#include <MXLogger/MXLogger.h>


#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func


/// 初始化logger: 创建(或复用)OC层MXLogger对象，返回其指针作为Dart侧持有的句柄
/// Initialize the logger: create (or reuse) the Objective-C MXLogger instance and
/// return its pointer as the handle held by the Dart side
MXLOGGER_EXPORT int64_t MXLOGGERR_FUNC(initialize)(const char* ns,const char* directory,const char* storage_policy,const char* file_name, const char* file_header,const char* crypt_key, const char* iv){


    NSString * _ns = [NSString stringWithUTF8String:ns];
    NSString * _directory = [NSString stringWithUTF8String:directory];
    NSString * _storagePolicy = storage_policy == nullptr ? NULL : [NSString stringWithUTF8String:storage_policy];
    NSString * _fileName = file_name == nullptr ? NULL : [NSString stringWithUTF8String:file_name];
    NSString * _fileHeader = file_header == nullptr ? NULL : [NSString stringWithUTF8String:file_header];
    NSString * _cryptKey = crypt_key == nullptr ? NULL : [NSString stringWithUTF8String:crypt_key];
    NSString * _iv = iv == nullptr ? NULL : [NSString stringWithUTF8String:iv];

    MXStoragePolicyType policyType = MXStoragePolicyYYYYMMDD;

    if([_storagePolicy isEqualToString:@"yyyy_MM_dd"]){
        policyType = MXStoragePolicyYYYYMMDD;
    }else if ([_storagePolicy isEqualToString:@"yyyy_MM_dd_HH"]){
        policyType = MXStoragePolicyYYYYMMDDHH;
    }else if ([_storagePolicy isEqualToString:@"yyyy_ww"]){
        policyType = MXStoragePolicyYYYYWW;
    }else if ([_storagePolicy isEqualToString:@"yyyy_MM"]){
        policyType = MXStoragePolicyYYYYMM;
    }

    MXLogger * logger = [MXLogger initializeWithNamespace:_ns diskCacheDirectory:_directory storagePolicy:policyType fileName:_fileName fileHeader:_fileHeader  cryptKey:_cryptKey iv:_iv];
    // flutter端直接禁掉控制台输出 由flutter层面进行输出；
    // 过期清理也交由flutter层的生命周期监听触发 这里关掉OC层的进后台自动清理
    // Console output is disabled here — the Flutter layer handles it via debugPrint;
    // expired-file cleanup is also driven by the Flutter layer's lifecycle observer,
    // so the OC-side enter-background auto-cleanup is turned off
    logger.consoleEnable = NO;
    logger.shouldRemoveExpiredDataWhenEnterBackground = NO;

    return (int64_t)logger;
}

/// 通过nameSpace+directory销毁logger对象
/// Destroy the logger identified by nameSpace + directory
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    [MXLogger destroyWithNamespace:[NSString stringWithUTF8String:ns] diskCacheDirectory:directory == nullptr ? NULL : [NSString stringWithUTF8String:directory]];
}


/// 通过loggerKey销毁logger对象
/// Destroy the logger identified by loggerKey
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroyWithLoggerKey)(const char* logger_key){
    if(logger_key == nullptr)return;

    [MXLogger destroyWithLoggerKey:[NSString stringWithUTF8String:logger_key]];
}



/// 开启/关闭native侧控制台输出
/// (Dart侧当前未绑定此符号，控制台输出统一由flutter层debugPrint实现，符号保留以兼容旧版本)
/// Enable or disable native-side console output
/// (currently not bound on the Dart side — console output goes through the Flutter
/// layer's debugPrint; the symbol is kept for backward compatibility)
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.consoleEnable = enable;
}

/// 开启/禁用日志写入 非0开启 0禁用
/// Enable or disable logging: non-zero to enable, 0 to disable
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.enable = enable != 0;
}



/// 解析(解密)日志文件: 每条日志序列化为一个JSON字符串，通过array_ptr/size_array_ptr输出，
/// number返回条数；底层selectWithDiskCacheFilePath已按倒序返回(最新的记录在前)。
/// 返回 0成功 -1失败；输出的内存必须调用free_logmsg释放
/// Parse (and decrypt) a log file: each entry is serialized to a JSON string and returned
/// via array_ptr/size_array_ptr, with the count in number; the underlying
/// selectWithDiskCacheFilePath already returns entries newest first.
/// Returns 0 on success, -1 on failure; the output memory must be freed with free_logmsg
MXLOGGER_EXPORT int MXLOGGERR_FUNC(select_logmsg)(const char * diskcache_file_path, const char* crypt_key, const char* iv,int* number, char ***array_ptr,uint32_t **size_array_ptr){
    *number = 0;
    if(diskcache_file_path == nullptr){
        return -1;
    }


    NSArray<NSDictionary*> * resultArray =   [MXLogger selectWithDiskCacheFilePath:[NSString stringWithUTF8String:diskcache_file_path] cryptKey:crypt_key == nullptr ? NULL : [NSString stringWithUTF8String:crypt_key] iv:iv == nullptr ? NULL : [NSString stringWithUTF8String:iv]];

    int count = (int)resultArray.count;
    if(count <= 0) return 0;

    auto array = (char**)malloc(count * sizeof(char *));
    auto size_array = (uint32_t *) malloc(count * sizeof(uint32_t));
    if(array == nullptr || size_array == nullptr){
        free(array);
        free(size_array);
        return -1;
    }
    for(int i = 0;i<count;i++){
        NSData *logData = [NSJSONSerialization dataWithJSONObject:resultArray[i]
                                                          options:NSJSONWritingPrettyPrinted
                                                            error:NULL];
        NSUInteger length = logData.length;
        // NSData由ARC管理 函数返回后即失效 必须拷贝到native堆 由free_logmsg配对释放
        // NSData is ARC-managed and dies after this function returns — the bytes must be
        // copied onto the native heap and freed by the paired free_logmsg call
        char *buffer = (char *)malloc(length > 0 ? length : 1);
        if(buffer == nullptr || logData == nil){
            for(int j = 0;j<i;j++) free(array[j]);
            free(buffer);
            free(array);
            free(size_array);
            return -1;
        }
        memcpy(buffer, logData.bytes, length);
        array[i] = buffer;
        size_array[i] = static_cast<uint32_t>(length);
    }

    *array_ptr = array;
    *size_array_ptr = size_array;
    *number = count;
    return 0;

}

/// 释放select_logmsg返回的内存 必须与select_logmsg成对调用
/// Free the memory returned by select_logmsg; must be paired with each select_logmsg call
MXLOGGER_EXPORT void MXLOGGERR_FUNC(free_logmsg)(int number, char **array, uint32_t *size_array){
    if(array != nullptr){
        for(int i = 0;i<number;i++) free(array[i]);
        free(array);
    }
    free(size_array);
}

/// 获取日志文件列表: 每个文件输出4个字段(name/size/last_timestamp/create_timestamp)，
/// 返回文件个数；输出的内存由Dart侧遍历释放
/// Get the list of log files: each file yields 4 fields
/// (name/size/last_timestamp/create_timestamp); returns the file count.
/// The output memory is freed by the Dart side while iterating
MXLOGGER_EXPORT int MXLOGGERR_FUNC(get_logfiles)(const void *handle,char ****array_ptr,uint32_t ***size_array_ptr){
    MXLogger *logger = (__bridge MXLogger *) handle;
    NSArray<NSDictionary<NSString*,NSString*>*>* fileArray =  [logger logFiles];
    if(fileArray.count == 0) return 0;
    auto array = (char***)malloc(fileArray.count * sizeof(void *));

    auto size_array = (uint32_t **) malloc(fileArray.count * sizeof(uint32_t *));
            /// 两块内存任一分配失败都要放弃，只检查array会在下方对空size_array解引用
            /// Bail out if either allocation fails — checking only array would
            /// dereference a null size_array below
            if(!array || !size_array){
                free(array);
                free(size_array);
                return 0;
            }
    *array_ptr = array;
    *size_array_ptr = size_array;


    for(int i=0; i< fileArray.count;i++){
        NSDictionary<NSString*,NSString*>* map = fileArray[i];

        NSString * name = [map valueForKey:@"name"];

        NSString * size = [map valueForKey:@"size"];

        NSString * last_timestamp = [map valueForKey:@"last_timestamp"];

        NSString * create_timestamp  =  [map valueForKey:@"create_timestamp"];


         char* c_name =  (char*)name.UTF8String;
         char* c_size = (char*)size.UTF8String;
         char* c_last_timestamp = (char*)last_timestamp.UTF8String;
         char* c_create_timestamp = (char*)create_timestamp.UTF8String;

        auto itemArray = (char**)malloc(4*sizeof(char*));

        itemArray[0] = (char*)malloc(strlen(c_name));
        memcpy(itemArray[0], c_name, strlen(c_name));


        itemArray[1] = (char*)malloc(strlen(c_size));
        memcpy(itemArray[1], c_size, strlen(c_size));

        itemArray[2] = (char*)malloc(strlen(c_last_timestamp));
        memcpy(itemArray[2], c_last_timestamp, strlen(c_last_timestamp));

        itemArray[3] = (char*)malloc(strlen(c_create_timestamp));
        memcpy(itemArray[3], c_create_timestamp, strlen(c_create_timestamp));



        /// 元素类型是uint32_t，原来误写成sizeof(uint32_t*)多分配了一倍内存
        /// The element type is uint32_t; sizeof(uint32_t*) over-allocated by 2x
        auto item_size_array = (uint32_t *) malloc(4 * sizeof(uint32_t));

        item_size_array[0] = static_cast<uint32_t>(strlen(c_name));
        item_size_array[1] = static_cast<uint32_t>(strlen(c_size));
        item_size_array[2] = static_cast<uint32_t>(strlen(c_last_timestamp));
        item_size_array[3] = static_cast<uint32_t>(strlen(c_create_timestamp));

        size_array[i] = item_size_array;
        array[i] = itemArray;
    }
    return (int)fileArray.count;
}

/// 未实现 保留导出仅为兼容Dart侧的符号绑定
/// Not implemented; the export is kept only so the Dart-side symbol binding succeeds
MXLOGGER_EXPORT uint32_t MXLOGGERR_FUNC(select_logfiles)(const char * directory, char ***array_ptr,uint32_t **size_array_ptr){
    return 0;
}


/// 设置写入文件的日志等级 低于该等级的日志不会写入
/// Set the minimum level written to file; logs below this level are not written
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_level)(const void *handle,int level){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.level = [NSNumber numberWithInt:level].integerValue;
}

/// 设置日志文件最大存储时长(秒)
/// Set the maximum age of log files in seconds
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(const void *handle,int max_age){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.maxDiskAge = max_age;

}

/// 设置日志文件最大字节数(byte)
/// 参数固定为int32_t与Dart侧Int32严格匹配(上限约2GB，对日志足够)，与Android桥接保持一致
/// Set the maximum total size of log files in bytes.
/// The parameter is int32_t to exactly match Int32 on the Dart side (capped at ~2GB,
/// plenty for logs), consistent with the Android bridge
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)(const void *handle,int32_t max_size){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.maxDiskSize = (NSUInteger)max_size;
}

/// 获取存储的日志大小(byte) 返回int32_t与Dart侧Int32严格匹配
/// (原unsigned long为8字节，与Dart声明的32位不匹配)
/// Get the total size of stored logs in bytes; returns int32_t to exactly match Int32
/// on the Dart side (the previous unsigned long was 8 bytes and mismatched
/// the 32-bit Dart declaration)
MXLOGGER_EXPORT int32_t MXLOGGERR_FUNC(get_log_size)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return (int32_t)logger.logSize;
}

/// UTF8String挂在autorelease pool上 不能直接跨FFI边界返回 必须拷贝到堆上 由free_string配对释放
/// UTF8String lives in the autorelease pool and cannot cross the FFI boundary directly —
/// it must be copied onto the heap and freed by the paired free_string call
static char * mx_copy_string_(NSString *str){
    if(str == nil) return nullptr;
    const char *utf8 = str.UTF8String;
    return utf8 == nullptr ? nullptr : strdup(utf8);
}

/// 获取logger的唯一标识loggerKey (nameSpace+diskCacheDirectory的md5值)
/// Get the logger's unique key (the md5 of nameSpace + diskCacheDirectory)
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_loggerKey)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_(logger.loggerKey);
}


/// 获取日志文件磁盘缓存目录
/// Get the disk-cache directory of the log files
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_diskcache_path)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_(logger.diskCachePath);
}

/// 获取最近一次写入失败的错误信息
/// Get the most recent write-error description
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_error_desc)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_([logger errorDesc]);
}

/// 释放get_loggerKey/get_diskcache_path/get_error_desc返回的字符串
/// Free the strings returned by get_loggerKey / get_diskcache_path / get_error_desc
MXLOGGER_EXPORT void MXLOGGERR_FUNC(free_string)(char *str){
    free(str);
}


/// 删除除当前正在写入文件之外的所有日志文件
/// Remove all log files except the one currently being written
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_before_all_data)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeBeforeAllData];
}

/// 清理过期日志文件
/// Remove expired log files
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeExpireData];
}

/// 删除所有日志文件
/// Remove all log files
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeAllData];
}

/// 通过loggerKey写入日志: 查找已初始化的logger对象进行写入，不存在时向nil发消息返回0
/// Write a log entry via loggerKey: looks up the already-initialized logger and writes
/// to it; when no logger matches, the message goes to nil and 0 is returned
MXLOGGER_EXPORT int MXLOGGERR_FUNC(log_loggerKey)(const char* logger_key,const char* name, int lvl,const char* msg,const char* tag){
    if(logger_key == nullptr) return 0;

    MXLogger *logger = [MXLogger valueForLoggerKey:[NSString stringWithUTF8String:logger_key]];

    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _msg = msg == nullptr ? NULL : [NSString stringWithUTF8String:msg];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];

    return  [logger logWithLevel:lvl name:_name msg: _msg tag:_tag];

}


/// 通过句柄写入日志
/// 返回 0成功 -1扩容失败 -2解除映射失败 -3映射失败
/// Write a log entry via the handle
/// Returns 0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
MXLOGGER_EXPORT int MXLOGGERR_FUNC(log)(const void *handle,const char* name, int lvl,const char* msg,const char* tag){
    MXLogger *logger = (__bridge MXLogger *) handle;

    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _msg = msg == nullptr ? NULL : [NSString stringWithUTF8String:msg];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];

    return  [logger logWithLevel:lvl name:_name msg: _msg tag:_tag];


}



/// 占位类: 保证该.mm文件被链接器保留(纯C导出符号的OC文件可能被strip)
/// Dummy class: keeps this .mm file from being stripped by the linker
/// (an Objective-C file with only C exports may otherwise be dropped)
@interface MXLoggerDummy : NSObject
@end

@implementation MXLoggerDummy
@end
