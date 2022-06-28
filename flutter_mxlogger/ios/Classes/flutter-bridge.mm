//
//  flutter-bridge.m
//  Logger
//
//  Created by 董家祎 on 2022/3/11.
//
//

#include <MXLogger/MXLogger.h>


#define MXLOGGER_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))
#define MXLOGGERR_FUNC(func) flutter_mxlogger_ ## func


MXLOGGER_EXPORT int64_t MXLOGGERR_FUNC(initialize)(const char* ns,const char* directory,const char* storage_policy,const char* file_name,const char* crypt_key, const char* iv){
  
    
    NSString * _ns = [NSString stringWithUTF8String:ns];
    NSString * _directory = [NSString stringWithUTF8String:directory];
    NSString * _storagePolicy = storage_policy == nullptr ? NULL : [NSString stringWithUTF8String:storage_policy];
    NSString * _fileName = file_name == nullptr ? NULL : [NSString stringWithUTF8String:file_name];
    NSString * _cryptKey = crypt_key == nullptr ? NULL : [NSString stringWithUTF8String:crypt_key];
    NSString * _iv = iv == nullptr ? NULL : [NSString stringWithUTF8String:iv];
    
    MXLogger * logger = [MXLogger initializeWithNamespace:_ns diskCacheDirectory:_directory storagePolicy:_storagePolicy fileName:_fileName cryptKey:_cryptKey iv:_iv];
        
  
    logger.shouldRemoveExpiredDataWhenTerminate = NO;
    logger.shouldRemoveExpiredDataWhenEnterBackground = NO;
    
    return (int64_t)logger;
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    [MXLogger destroyWithNamespace:[NSString stringWithUTF8String:ns] diskCacheDirectory:directory == nullptr ? NULL : [NSString stringWithUTF8String:directory]];
}




MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.consoleEnable = enable;
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.enable = enable == 1 ? YES : NO;
}



MXLOGGER_EXPORT int MXLOGGERR_FUNC(select_logmsg)(const char * diskcache_file_path, const char* crypt_key, const char* iv,int* number, char ***array_ptr,uint32_t **size_array_ptr){
    if(diskcache_file_path == nullptr){
        return -1;
    }
    
    
    NSArray<NSDictionary*> * resultArray =   [MXLogger selectWithDiskCacheFilePath:[NSString stringWithUTF8String:diskcache_file_path] cryptKey:crypt_key == nullptr ? NULL : [NSString stringWithUTF8String:crypt_key] iv:iv == nullptr ? NULL : [NSString stringWithUTF8String:iv]];
    
    int count = (int)resultArray.count;
    
    *number = count;
    
    if(count > 0){
        auto array = (char**)malloc(count * sizeof(void *));
        auto size_array = (uint32_t *) malloc(count * sizeof(uint32_t *));
        if(!array){
            free(array);
            free(size_array);
            return -1;
        }
        *array_ptr = array;
        *size_array_ptr = size_array;
        for(int i = 0;i<count;i++){
            NSDictionary * logdictionary = resultArray[i];
            
            NSData *logData = [NSJSONSerialization dataWithJSONObject:logdictionary
                                                               options:NSJSONWritingPrettyPrinted
                                                                 error:NULL];
            NSUInteger length = logData.length;
            size_array[i] = static_cast<uint32_t>(length);
    
            array[i] = (char*)logData.bytes;
        }
    }
    
    return 0;
    
}
MXLOGGER_EXPORT uint32_t MXLOGGERR_FUNC(select_logfiles)(const char * directory, char ***array_ptr,uint32_t **size_array_ptr){
    if(directory == nullptr) return 0;
    
    
    NSArray<NSDictionary<NSString*,NSString*>*>* list =  [MXLogger selectLogfilesWithDirectory:[NSString stringWithUTF8String:directory]];
    if(list.count > 0){
        auto array = (char**)malloc(list.count * sizeof(void *));
        auto size_array = (uint32_t *) malloc(list.count * sizeof(uint32_t *));
        if(!array){
            free(array);
            free(size_array);
            return 0;
        }
        *array_ptr = array;
        *size_array_ptr = size_array;
        
        for(int i =0;i < list.count;i++){
            NSDictionary<NSString*,NSString*>* map = list[i];
            NSString * info = [NSString  stringWithFormat:@"%@,%@,%@",map[@"name"],map[@"size"],map[@"timestamp"]];
            auto infoData = [info dataUsingEncoding:NSUTF8StringEncoding];
            size_array[i] = static_cast<uint32_t>(infoData.length);
            array[i] = (char*)infoData.bytes;
        }
        return static_cast<uint32_t>(list.count);
    }
    
    return 0;
    
}



MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_age)(const void *handle,int max_age){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.maxDiskAge = max_age;

}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_max_disk_size)(const void *handle,uint max_size){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.maxDiskSize = max_size;
}
MXLOGGER_EXPORT unsigned long MXLOGGERR_FUNC(get_log_size)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return logger.logSize;
}


MXLOGGER_EXPORT const char* MXLOGGERR_FUNC(get_diskcache_path)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return logger.diskCachePath.UTF8String;
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeExpireData];
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeAllData];
}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(log)(const void *handle,const char* name, int lvl,const char* msg,const char* tag){
    MXLogger *logger = (__bridge MXLogger *) handle;
   
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _msg = msg == nullptr ? NULL : [NSString stringWithUTF8String:msg];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
   
    [logger log:lvl name:_name msg: _msg tag:_tag];

}




@interface MXLoggerDummy : NSObject
@end

@implementation MXLoggerDummy
@end

