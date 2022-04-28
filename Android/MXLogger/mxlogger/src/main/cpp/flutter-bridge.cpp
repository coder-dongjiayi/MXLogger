//
// Created by 董家祎 on 2022/4/11.
//

#include "mxlogger.hpp"
using namespace mxlogger;
using namespace std;
#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func


MXLOGGER_EXPORT int64_t MXLOGGERR_FUNC(initialize)(const char* ns,const char* directory){

    mx_logger * logger =  mx_logger ::initialize_namespace(ns,directory);

    return (int64_t)logger;
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    mx_logger::delete_namespace(ns,directory);
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_level)(void *handle, int lvl){
    mx_logger *logger = static_cast<mx_logger*>(handle);
  logger -> set_file_level(lvl);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_level)( void *handle,int lvl){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_console_level(lvl);
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_enable)( void *handle,int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_file_enable(enable == 0 ? false : true);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)( void *handle,int enable){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_console_enable(enable == 0 ? false : true);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_header)( void *handle,const char* header){
    if(header == nullptr) return;
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_file_header(header);

}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)( void *handle,int max_age){

    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_file_max_age(max_age);


}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)(void *handle,uint max_size){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_file_max_size(max_size);

}
MXLOGGER_EXPORT unsigned long MXLOGGERR_FUNC(get_log_size)( void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger ->file_size();
}
MXLOGGER_EXPORT int MXLOGGERR_FUNC(is_debug_tracking)( void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger -> is_debug_tracking();
}
MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)( void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    return logger ->diskcache_path();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_name)(void *handle,const char* file_name){
    if(file_name == nullptr) return;
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger ->set_file_name(file_name);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)( void *handle){
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> remove_expire_data();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)( void *handle){

    mx_logger *logger = static_cast<mx_logger*>(handle);

    logger -> remove_all();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_storage_policy)( void *handle,const char* policy){
    if(policy == nullptr) return;
    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger ->set_file_policy(policy);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_pattern)( void *handle,const char*pattern){
    if(pattern == nullptr) return;
    mx_logger *logger = static_cast<mx_logger*>(handle);
   logger -> set_file_pattern(pattern);


}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_pattern)( void *handle,const char*pattern){
    if(pattern == nullptr) return;

    mx_logger *logger = static_cast<mx_logger*>(handle);
    logger -> set_console_pattern(pattern);


}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(log)( void *handle,const char* name, int lvl,const char* msg,const char* tag){
    mx_logger *logger = static_cast<mx_logger*>(handle);

   logger ->log(0,lvl,name,msg,tag,false);

}


