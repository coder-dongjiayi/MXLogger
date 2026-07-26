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
     //flutter端直接禁掉控制台输出 由flutter层面进行输出
    logger.consoleEnable = NO;
    logger.shouldRemoveExpiredDataWhenEnterBackground = NO;
    
    return (int64_t)logger;
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroy)(const char* ns,const char* directory){
    [MXLogger destroyWithNamespace:[NSString stringWithUTF8String:ns] diskCacheDirectory:directory == nullptr ? NULL : [NSString stringWithUTF8String:directory]];
}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(destroyWithLoggerKey)(const char* logger_key){
    if(logger_key == nullptr)return;
    
    [MXLogger destroyWithLoggerKey:[NSString stringWithUTF8String:logger_key]];
}




MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_console_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.consoleEnable = enable;
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_enable)(const void *handle,int enable){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.enable = NO;
}




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
MXLOGGER_EXPORT void MXLOGGERR_FUNC(free_logmsg)(int number, char **array, uint32_t *size_array){
    if(array != nullptr){
        for(int i = 0;i<number;i++) free(array[i]);
        free(array);
    }
    free(size_array);
}
/// 获取日志文件列表
MXLOGGER_EXPORT int MXLOGGERR_FUNC(get_logfiles)(const void *handle,char ****array_ptr,uint32_t ***size_array_ptr){
    MXLogger *logger = (__bridge MXLogger *) handle;
    NSArray<NSDictionary<NSString*,NSString*>*>* fileArray =  [logger logFiles];
    if(fileArray.count == 0) return 0;
    auto array = (char***)malloc(fileArray.count * sizeof(void *));
    
    auto size_array = (uint32_t **) malloc(fileArray.count * sizeof(uint32_t *));
            if(!array){
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

   
        
        auto item_size_array = (uint32_t *) malloc(4 * sizeof(uint32_t *));
               
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
MXLOGGER_EXPORT uint32_t MXLOGGERR_FUNC(select_logfiles)(const char * directory, char ***array_ptr,uint32_t **size_array_ptr){
    return 0;
}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(set_level)(const void *handle,int level){
    MXLogger *logger = (__bridge MXLogger *) handle;
    logger.level = [NSNumber numberWithInt:level].integerValue;
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

/// UTF8String挂在autorelease pool上 不能直接跨FFI边界返回 必须拷贝到堆上 由free_string配对释放
static char * mx_copy_string_(NSString *str){
    if(str == nil) return nullptr;
    const char *utf8 = str.UTF8String;
    return utf8 == nullptr ? nullptr : strdup(utf8);
}

MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_loggerKey)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_(logger.loggerKey);
}


MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_diskcache_path)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_(logger.diskCachePath);
}
MXLOGGER_EXPORT char* MXLOGGERR_FUNC(get_error_desc)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    return mx_copy_string_([logger errorDesc]);
}

/// 释放get_loggerKey/get_diskcache_path/get_error_desc返回的字符串
MXLOGGER_EXPORT void MXLOGGERR_FUNC(free_string)(char *str){
    free(str);
}


MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_before_all_data)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeBeforeAllData];
}

MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_expire_data)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeExpireData];
}
MXLOGGER_EXPORT void MXLOGGERR_FUNC(remove_all)(const void *handle){
    MXLogger *logger = (__bridge MXLogger *) handle;
    [logger removeAllData];
}
 
MXLOGGER_EXPORT int MXLOGGERR_FUNC(log_loggerKey)(const char* logger_key,const char* name, int lvl,const char* msg,const char* tag){
    if(logger_key == nullptr) return 0;
    
    MXLogger *logger = [MXLogger valueForLoggerKey:[NSString stringWithUTF8String:logger_key]];
    
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _msg = msg == nullptr ? NULL : [NSString stringWithUTF8String:msg];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
    return  [logger logWithLevel:lvl name:_name msg: _msg tag:_tag];
    
}


MXLOGGER_EXPORT int MXLOGGERR_FUNC(log)(const void *handle,const char* name, int lvl,const char* msg,const char* tag){
    MXLogger *logger = (__bridge MXLogger *) handle;
   
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _msg = msg == nullptr ? NULL : [NSString stringWithUTF8String:msg];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
    return  [logger logWithLevel:lvl name:_name msg: _msg tag:_tag];


}




@interface MXLoggerDummy : NSObject
@end

@implementation MXLoggerDummy
@end

