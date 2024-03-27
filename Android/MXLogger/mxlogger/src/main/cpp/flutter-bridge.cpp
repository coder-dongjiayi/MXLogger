////
//// Created by 董家祎 on 2022/4/11.
////
//
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
#include "debug_log.hpp"
using namespace mxlogger;
using namespace std;
#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func

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

    return int64_t(logger);

}
MXLOGGER_EXPORT int MXLOGGERR_FUNC(select_logmsg)(const char * diskcache_file_path, const char* crypt_key, const char* iv,int* number, char ***array_ptr,uint32_t **size_array_ptr){
    if(diskcache_file_path == nullptr){
        return -1;
    }

    std::vector<std::map<std::string, std::string>> destination;

    util::mxlogger_util::select_log_form_path(diskcache_file_path, &destination,crypt_key,iv);


    int count = (int)destination.size();

    *number = count;

//    if(count > 0){
//        auto array = (char**)malloc(count * sizeof(void *));
//        auto size_array = (uint32_t *) malloc(count * sizeof(uint32_t *));
//        if(!array){
//            free(array);
//            free(size_array);
//            return -1;
//        }
//        *array_ptr = array;
//        *size_array_ptr = size_array;
//        for(int i = 0;i<count;i++){
//            std::map<std::string, std::string>  logdictionary = destination[i];
//
//            NSData *logData = [NSJSONSerialization dataWithJSONObject:logdictionary
//            options:NSJSONWritingPrettyPrinted
//            error:NULL];
//            NSUInteger length = logData.length;
//            size_array[i] = static_cast<uint32_t>(length);
//
//            array[i] = (char*)logData.bytes;
//        }
//    }

    return 0;

}
/// 获取日志文件列表
MXLOGGER_EXPORT int MXLOGGERR_FUNC(get_logfiles)(void *handle,char ****array_ptr,uint32_t ***size_array_ptr){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    std::vector<std::map<std::string, std::string>> destination;

    util::mxlogger_util::select_logfiles_dir(logger->diskcache_path(),&destination);

    if(destination.size() == 0) return 0;

    auto array = (char***)malloc(destination.size() * sizeof(void *));

    auto size_array = (uint32_t **) malloc(destination.size() * sizeof(uint32_t *));
    if(!array){
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

        auto item_size_array = (uint32_t *) malloc(4 * sizeof(uint32_t *));

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
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    mx_logger ::delete_namespace(ns,directory);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroyWithLoggerKey)(const char* logger_key){
    if(logger_key == nullptr)return;
    mx_logger ::delete_namespace(logger_key);
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(void *handle, int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_enable_console(enable);
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_enable)(void *handle,int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger ->set_enable(enable == 1 ? true : false);
}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(void *handle,int max_age){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->set_file_max_age(max_age);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)( void *handle,long max_size){

    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_file_max_size(max_size);
}
MXLOGGER_EXPORT int MXLOGGERR_FUNC(get_log_size)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger->dir_size();
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_level)(void *handle,int level){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_log_level(level);

}

MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_loggerKey)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger ->logger_key();
}

MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger->diskcache_path();
}

MXLOGGER_EXPORT const char * MXLOGGERR_FUNC(get_error_desc)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return  logger->error_desc();
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_before_all_data)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->remove_before_all();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_expire_data();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_all();
}

MXLOGGER_EXPORT int MXLOGGERR_FUNC(log_loggerKey)(const char* logger_key,const char* name, int lvl,const char* msg,const char* tag){
    if(logger_key == nullptr) return 0;

    mx_logger *logger = mx_logger::global_for_loggerKey(logger_key);

   return logger->log(lvl,name,msg,tag,true);

}

MXLOGGER_EXPORT int MXLOGGERR_FUNC(log)(void *handle,const char* name, int lvl,const char* msg,const char* tag){
    mx_logger *logger = static_cast<mx_logger*>(handle);

   return logger->log(lvl,name,msg,tag,true);

}
