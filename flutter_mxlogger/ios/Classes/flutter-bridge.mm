//
//  flutter-bridge.m
//  Logger
//
//  Created by 董家祎 on 2022/3/11.
//

#include "mxlogger_manager.hpp"

using namespace mxlogger;
using namespace std;

#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func
level::level_enum _get_level(int level){
    level::level_enum lvl = level::level_enum::debug;
    switch (level) {
        case 0:
            lvl = level::level_enum::debug;
            break;
        case 1:
            lvl = level::level_enum::info;
            break;
        case 2:
            lvl = level::level_enum::warn;
            break;
        case 3:
            lvl = level::level_enum::error;
            break;
        case 4:
            lvl = level::level_enum::fatal;

        default:
            break;
    }
    return lvl;
}


MXLOGGER_EXPORT int MXLOGGERR_FUNC(initWithNamespace)(const char* ns,const char* directory){

   char file_path [255];

    sprintf(file_path,"%s/%s/",directory,ns);

    char dir[255];
    
    strcpy(dir, file_path);
    
    mx_logger ::instance().set_file_dir(dir);

    return 1;
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_level)(int lvl){
     mxlogger_manager::instance().set_file_level(_get_level(lvl));
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_level)(int lvl){
     mxlogger_manager::instance().set_console_level(_get_level(lvl));
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_enable)(int enable){
    mxlogger_manager::instance().set_file_enable(enable == 1 ? true : false);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(int enable){
    mxlogger_manager::instance().set_console_enable(enable == 1 ? true : false);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_header)(const char* header){
    if(header == nullptr) return;
    mxlogger_manager::instance().set_file_header(header);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_is_async)(int is_async){
    mxlogger_manager::instance().set_file_async(is_async);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(int max_age){
    mxlogger_manager::instance().set_file_max_age(max_age);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)(uint max_size){
    mxlogger_manager::instance().set_file_max_size(max_size);
}
MXLOGGER_EXPORT unsigned long MXLOGGERR_FUNC(get_log_size)(){

    return mxlogger_manager::instance().file_size();
}
MXLOGGER_EXPORT int MXLOGGERR_FUNC(is_debug_tracking)(){

    return mxlogger_manager::instance().is_debuging() ? 1 : 0;
}
MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)(){

    return mxlogger_manager::instance().file_diskcache_path();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_name)(const char* file_name){
    if(file_name == nullptr) return;
    mxlogger_manager::instance().set_file_name(file_name);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(){
    mxlogger_manager::instance().remove_expire_data();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(){
    mxlogger_manager::instance().remove_all();
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_storage_policy)(const char* policy){
    if(policy == nullptr) return;
    policy::storage_policy  storage_policy = policy::storage_policy::yyyy_MM_dd;

    if (strcmp("yyyy_MM",policy) == 0){
        storage_policy = policy::storage_policy::yyyy_MM;
    }else if(strcmp("yyyy_MM_dd",policy)  == 0){
        storage_policy = policy::storage_policy::yyyy_MM_dd;
    }else if (strcmp("yyyy_ww",policy) == 0){
        storage_policy = policy::storage_policy::yyyy_ww;
    }else if (strcmp("yyyy_MM_dd_HH",policy) == 0){
        storage_policy =  policy::storage_policy::yyyy_MM_dd_HH;
    }
    mx_logger ::instance().set_file_policy(storage_policy);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_pattern)(const char*pattern){
    if(pattern == nullptr) return;
    mx_logger ::instance().set_file_pattern(pattern);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_pattern)(const char*pattern){
    if(pattern == nullptr) return;
    mx_logger ::instance().set_console_pattern(pattern);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(log)(const char* name, int lvl,const char* msg,const char* tag){


    mx_logger ::instance().log(log_type::all,_get_level(lvl),name,msg,tag,false);
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(async_log_file)(const char* name, int lvl,const char* msg,const char* tag){

    mx_logger ::instance().log_async_file(_get_level(lvl),name,msg,tag,false);

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(sync_log_file)(const char* name, int lvl,const char* msg,const char* tag){

    mx_logger ::instance().log_sync_file(_get_level(lvl),name,msg,tag,false);
}


@interface MXLoggerDummy : NSObject
@end

@implementation MXLoggerDummy
@end

