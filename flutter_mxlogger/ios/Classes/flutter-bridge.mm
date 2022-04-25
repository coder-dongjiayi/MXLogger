//
//  flutter-bridge.m
//  Logger
//
//  Created by 董家祎 on 2022/3/11.
//
//

#include <MXLogger/MXLogger.h>
#include <MXLoggerCore/mxlogger.hpp>
#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func


MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_level)(const void *handle, int lvl){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.fileLevel = lvl;
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_level)(const void *handle,int lvl){
    mx_logger::initialize_namespace("", "");
  
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_enable)(const void *handle,int enable){
 
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(const void *handle,int enable){
  
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_header)(const void *handle,const char* header){
    if(header == nullptr) return;
  
}



MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(const void *handle,int max_age){
    

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)(const void *handle,uint max_size){
  
}
MXLOGGER_EXPORT unsigned long MXLOGGERR_FUNC(get_log_size)(const void *handle){
  
    return 1;
}
MXLOGGER_EXPORT int MXLOGGERR_FUNC(is_debug_tracking)(const void *handle){
   
    return 1;
}
MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)(const void *handle){
   
    return "";
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_name)(const void *handle,const char* file_name){
    if(file_name == nullptr) return;
   
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(const void *handle){
   
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(const void *handle){
 
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_storage_policy)(const void *handle,const char* policy){
    if(policy == nullptr) return;
  
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_file_pattern)(const void *handle,const char*pattern){
    if(pattern == nullptr) return;
   

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_pattern)(const void *handle,const char*pattern){
    if(pattern == nullptr) return;


}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(log)(const void *handle,const char* name, int lvl,const char* msg,const char* tag){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger log:lvl name:[NSString stringWithUTF8String:name] msg:[NSString stringWithUTF8String:msg] tag:[NSString stringWithUTF8String:tag]];

}




@interface MXLoggerDummy : NSObject
@end

@implementation MXLoggerDummy
@end

