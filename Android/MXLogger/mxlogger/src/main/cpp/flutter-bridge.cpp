////
//// Created by 董家祎 on 2022/4/11.
////
// Flutter FFI桥接层: 以C符号(flutter_mxlogger_前缀)导出mxlogger核心能力，
// 供Dart侧通过dart:ffi的lookup绑定调用
// Flutter FFI bridge: exports the mxlogger core as C symbols (prefixed with
// flutter_mxlogger_) so the Dart side can bind them via dart:ffi lookup
//
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
#include "debug_log.hpp"
#include "json/cJSON.h"
using namespace mxlogger;
using namespace std;
#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func

/// 初始化logger: 创建(或复用)C++核心对象，返回其指针作为Dart侧持有的句柄，
/// ns或directory为空时返回0
/// Initialize the logger: create (or reuse) the C++ core instance and return its
/// pointer as the handle held by the Dart side; returns 0 when ns or directory is null
MXLOGGER_EXPORT int64_t MXLOGGERR_FUNC(initialize)(
        const char* ns,
        const char* directory,
        const char* storage_policy,
        const char* file_name,
        const char* file_header,
        const char* crypt_key,
        const char* iv){
    if (ns == nullptr || directory == nullptr) return 0;

    mx_logger * logger =   mx_logger ::initialize_namespace(ns,directory,storage_policy,file_name,file_header,crypt_key,iv);

    // flutter端控制台输出不走native 统一由flutter层debugPrint输出 这里显式禁掉native输出(与iOS桥接行为一致)
    // Console output on Flutter goes through the Flutter layer's debugPrint instead of
    // native code, so native output is explicitly disabled here (same as the iOS bridge)
    if (logger != nullptr){
        logger->set_enable_console(false);
    }

    return int64_t(logger);

}

/// 解析(解密)日志文件: 每条日志序列化为一个JSON字符串，通过array_ptr/size_array_ptr输出，
/// number返回条数；与iOS端selectWithDiskCacheFilePath对齐，倒序返回(最新的记录在前)。
/// 返回 0成功 -1失败；输出的内存必须调用free_logmsg释放
/// Parse (and decrypt) a log file: each entry is serialized to a JSON string and returned
/// via array_ptr/size_array_ptr, with the count in number; consistent with iOS
/// selectWithDiskCacheFilePath, entries come newest first.
/// Returns 0 on success, -1 on failure; the output memory must be freed with free_logmsg
MXLOGGER_EXPORT int MXLOGGERR_FUNC(select_logmsg)(const char * diskcache_file_path, const char* crypt_key, const char* iv,int* number, char ***array_ptr,uint32_t **size_array_ptr){
    *number = 0;
    if(diskcache_file_path == nullptr){
        return -1;
    }

    std::vector<std::map<std::string, std::string>> destination;

    util::mxlogger_util::select_log_form_path(diskcache_file_path, &destination,crypt_key,iv);


    int count = (int)destination.size();
    if(count <= 0) return 0;

    auto array = (char**)malloc(count * sizeof(char *));
    auto size_array = (uint32_t *) malloc(count * sizeof(uint32_t));
    if(array == nullptr || size_array == nullptr){
        free(array);
        free(size_array);
        return -1;
    }
    for(int i = 0;i<count;i++){
        // 与iOS端selectWithDiskCacheFilePath行为对齐: 返回倒序(最新的记录在前)
        // Consistent with iOS selectWithDiskCacheFilePath: reversed order (newest first)
        cJSON *item = cJSON_CreateObject();
        for(const auto &entry : destination[count - 1 - i]){
            cJSON_AddStringToObject(item, entry.first.c_str(), entry.second.c_str());
        }
        // cJSON默认分配器就是malloc 返回的串由free_logmsg配对释放
        // cJSON's default allocator is malloc; the returned string is freed by free_logmsg
        char *json = cJSON_PrintUnformatted(item);
        cJSON_Delete(item);
        if(json == nullptr){
            for(int j = 0;j<i;j++) free(array[j]);
            free(array);
            free(size_array);
            return -1;
        }
        array[i] = json;
        size_array[i] = static_cast<uint32_t>(strlen(json));
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
MXLOGGER_EXPORT int MXLOGGERR_FUNC(get_logfiles)(void *handle,char ****array_ptr,uint32_t ***size_array_ptr){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    std::vector<std::map<std::string, std::string>> destination;

    util::mxlogger_util::select_logfiles_dir(logger->diskcache_path(),&destination);

    if(destination.size() == 0) return 0;

    auto array = (char***)malloc(destination.size() * sizeof(void *));

    auto size_array = (uint32_t **) malloc(destination.size() * sizeof(uint32_t *));
    /// 两块内存任一分配失败都要放弃，只检查array会在下方对空size_array解引用
    /// Bail out if either allocation fails — checking only array would dereference
    /// a null size_array below
    if(!array || !size_array){
        free(array);
        free(size_array);
        return 0;
    }
    *array_ptr = array;
    *size_array_ptr = size_array;


    for(int i=0; i< destination.size();i++){
        std::map<std::string, std::string> map = destination[i];

         char *  c_name =  map["name"].data();
         char * c_size = map["size"].data();
         char *  c_last_timestamp =   map["last_timestamp"].data();
         char *  c_create_timestamp = map["create_timestamp"].data();

        auto itemArray = (char**)malloc(4*sizeof(char*));

        /// 元素类型是uint32_t，原来误写成sizeof(uint32_t*)多分配了一倍内存
        /// The element type is uint32_t; sizeof(uint32_t*) over-allocated by 2x
        auto item_size_array = (uint32_t *) malloc(4 * sizeof(uint32_t));

        item_size_array[0] = static_cast<uint32_t>(strlen(c_name));
        item_size_array[1] = static_cast<uint32_t>(strlen(c_size));
        item_size_array[2] = static_cast<uint32_t>(strlen(c_last_timestamp));
        item_size_array[3] = static_cast<uint32_t>(strlen(c_create_timestamp));

        itemArray[0] = (char*)malloc(strlen(c_name));
        memcpy(itemArray[0], c_name, strlen(c_name));


        itemArray[1] = (char*)malloc(strlen(c_size));
        memcpy(itemArray[1], c_size, strlen(c_size));

        itemArray[2] = (char*)malloc(strlen(c_last_timestamp));
        memcpy(itemArray[2], c_last_timestamp, strlen(c_last_timestamp));

        itemArray[3] = (char*)malloc(strlen(c_create_timestamp));
        memcpy(itemArray[3], c_create_timestamp, strlen(c_create_timestamp));


        size_array[i] = item_size_array;
        array[i] = itemArray;
    }
   int count =  (int)destination.size();
    return count;
}

/// 通过nameSpace+directory销毁C++对象
/// Destroy the C++ instance by nameSpace + directory
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    mx_logger ::delete_namespace(ns,directory);
}

/// 通过loggerKey销毁C++对象
/// Destroy the C++ instance by loggerKey
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroyWithLoggerKey)(const char* logger_key){
    if(logger_key == nullptr)return;
    mx_logger ::delete_namespace(logger_key);
}

/// 开启/关闭native侧控制台输出
/// (Dart侧当前未绑定此符号，控制台输出统一由flutter层debugPrint实现，符号保留以兼容旧版本)
/// Enable or disable native-side console output
/// (currently not bound on the Dart side — console output goes through the Flutter
/// layer's debugPrint; the symbol is kept for backward compatibility)
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(void *handle, int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_enable_console(enable);
}

/// 开启/禁用日志写入 1开启 0禁用
/// Enable or disable logging: 1 to enable, 0 to disable
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_enable)(void *handle,int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger ->set_enable(enable == 1 ? true : false);
}


/// 设置日志文件最大存储时长(秒)
/// Set the maximum age of log files in seconds
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(void *handle,int max_age){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->set_file_max_age(max_age);

}

/// 设置日志文件最大字节数(byte)
/// 参数固定为int32_t与Dart侧Int32严格匹配(上限约2GB，对日志足够)；
/// 不能用long：32位Android上是4字节、64位上是8字节，宽度随架构漂移会与Dart声明错位
/// Set the maximum total size of log files in bytes.
/// The parameter is int32_t to exactly match Int32 on the Dart side (capped at ~2GB,
/// plenty for logs); `long` must be avoided — 4 bytes on 32-bit Android but 8 bytes on
/// 64-bit, so its width drifts with the architecture and mismatches the Dart declaration
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)( void *handle,int32_t max_size){

    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_file_max_size(max_size);
}

/// 获取存储的日志大小(byte) 返回int32_t与Dart侧Int32严格匹配
/// Get the total size of stored logs in bytes;
/// returns int32_t to exactly match Int32 on the Dart side
MXLOGGER_EXPORT int32_t MXLOGGERR_FUNC(get_log_size)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return (int32_t)logger->dir_size();
}

/// 设置写入文件的日志等级 低于该等级的日志不会写入
/// Set the minimum level written to file; logs below this level are not written
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_level)(void *handle,int level){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_log_level(level);

}

/// 拷贝到堆上返回 由free_string配对释放 (与iOS端行为对齐 Dart侧统一释放)
/// Copy the string onto the heap; freed by the paired free_string call
/// (consistent with iOS — the Dart side owns the release)
static char * mx_copy_string_(const char *str){
    return str == nullptr ? nullptr : strdup(str);
}

/// 获取logger的唯一标识loggerKey (nameSpace+directory的md5值)
/// Get the logger's unique key (the md5 of nameSpace + directory)
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_loggerKey)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return mx_copy_string_(logger->logger_key());
}

/// 获取日志文件磁盘缓存目录
/// Get the disk-cache directory of the log files
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_diskcache_path)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return mx_copy_string_(logger->diskcache_path());
}

/// 获取最近一次写入失败的错误信息
/// Get the most recent write-error description
MXLOGGER_EXPORT char * MXLOGGERR_FUNC(get_error_desc)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return mx_copy_string_(logger->error_desc());
}

/// 释放get_loggerKey/get_diskcache_path/get_error_desc返回的字符串
/// Free the strings returned by get_loggerKey / get_diskcache_path / get_error_desc
MXLOGGER_EXPORT void MXLOGGERR_FUNC(free_string)(char *str){
    free(str);
}

/// 删除除当前正在写入文件之外的所有日志文件
/// Remove all log files except the one currently being written
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_before_all_data)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->remove_before_all();
}

/// 清理过期日志文件
/// Remove expired log files
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_expire_data();
}

/// 删除所有日志文件
/// Remove all log files
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_all();
}

/// 通过loggerKey写入日志: 查找已初始化的logger对象进行写入，
/// 不存在时静默返回0不报错(与JNI侧native_log_loggerKey、iOS侧行为对齐)
/// Write a log entry via loggerKey: looks up the already-initialized logger and writes
/// to it; silently returns 0 (no error) when no logger matches the key — consistent
/// with the JNI-side native_log_loggerKey and the iOS bridge
MXLOGGER_EXPORT int MXLOGGERR_FUNC(log_loggerKey)(const char* logger_key,const char* name, int lvl,const char* msg,const char* tag){
    if(logger_key == nullptr) return 0;

    mx_logger *logger = mx_logger::global_for_loggerKey(logger_key);
    if(logger == nullptr) return 0;

    return logger->log(lvl,name,msg,tag,true);

}

/// 通过句柄写入日志
/// 返回 0成功 -1扩容失败 -2解除映射失败 -3映射失败
/// Write a log entry via the handle
/// Returns 0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
MXLOGGER_EXPORT int MXLOGGERR_FUNC(log)(void *handle,const char* name, int lvl,const char* msg,const char* tag){
    mx_logger *logger = static_cast<mx_logger*>(handle);

   return logger->log(lvl,name,msg,tag,true);

}
