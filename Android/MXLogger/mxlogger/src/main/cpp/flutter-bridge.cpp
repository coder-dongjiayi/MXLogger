////
//// Created by 董家祎 on 2022/4/11.
////
//
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
using namespace mxlogger;
using namespace std;
#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func

MXLOGGER_EXPORT int64_t MXLOGGERR_FUNC(initialize)(const char* ns,
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
MXLOGGER_EXPORT uint32_t MXLOGGERR_FUNC(select_logfiles)(const char * directory, char ***array_ptr,uint32_t **size_array_ptr){
    if(directory == nullptr) return 0;

    std::vector<std::map<std::string, std::string>> destination;
    util::mxlogger_util::select_logfiles_dir(directory, &destination);

    if(destination.size() > 0){
        auto array = (char**)malloc(destination.size() * sizeof(void *));
        auto size_array = (uint32_t *) malloc(destination.size() * sizeof(uint32_t *));
        if(!array){
            free(array);
            free(size_array);
            return 0;
        }
        *array_ptr = array;
        *size_array_ptr = size_array;

        for(int i =0;i < destination.size();i++){
            std::map<std::string, std::string> map = destination[i];
            std::string  name = map["name"];
            std::string  size = map["size"];
            std::string  timestamp = map["timestamp"];

            std::string  infoStr = name + "," + size + "," + "timestamp";
            auto infoData = infoStr.data();
            size_array[i] = static_cast<uint32_t>(infoStr.size());
            array[i] = (char*)infoData;
        }
        return static_cast<uint32_t>(destination.size());
    }

    return 0;
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
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)( void *handle,uint max_size){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_file_max_size(max_size);
}
MXLOGGER_EXPORT unsigned long MXLOGGERR_FUNC(get_log_size)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger->dir_size();
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_level)(void *handle,int file_level){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger->set_file_level(file_level);

}

MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_loggerKey)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger ->logger_key();
}

MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger->diskcache_path();
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_expire_data();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->remove_all();
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(log_loggerKey)(const char* logger_key,const char* name, int lvl,const char* msg,const char* tag){
    if(logger_key == nullptr) return;

    mx_logger *logger = mx_logger::global_for_loggerKey(logger_key);

    logger->log(lvl,name,msg,tag,true);

}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(log)(void *handle,const char* name, int lvl,const char* msg,const char* tag){
    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger->log(lvl,name,msg,tag,true);

}
