//
//  flutter-bridge.m
//  Logger
//
//  Created by 董家祎 on 2022/3/11.
//


#import <MXLogger/MXLogger.h>

#define BLINGLOG_EXPORT extern "C" __attribute__((visibility("default"))) __attribute__((used))

#define BLINGLOG_FUNC(func) flutter_mxlogger_ ## func


BLINGLOG_EXPORT int BLINGLOG_FUNC(initWithNamespace)(const char* ns,const char* directory){
    
    NSString * _directory = directory == nullptr ? NULL : [NSString stringWithUTF8String:directory];
    
    id _manager =  [[MXLogger shareManager] initWithNamespace:[NSString stringWithUTF8String:ns] diskCacheDirectory:_directory];
    
    return _manager == NULL ? -1 : 0;
}


BLINGLOG_EXPORT void BLINGLOG_FUNC(set_file_level)(int lvl){
    [MXLogger shareManager].fileLevel = [[NSNumber numberWithInt:lvl] integerValue];
}
BLINGLOG_EXPORT void BLINGLOG_FUNC(set_file_enable)(int enable){
    [MXLogger shareManager].fileEnable = enable == 0 ? false : true;
}
BLINGLOG_EXPORT void BLINGLOG_FUNC(set_file_header)(const char* header){
    if(header == nullptr) return;
    
    [MXLogger shareManager].fileHeader = [NSString stringWithUTF8String:header];
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(set_is_async)(int is_async){
    [MXLogger shareManager].isAsync = is_async == 1 ? true : false;
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(set_remove_exporeddata_background)(int should){
    [MXLogger shareManager].shouldRemoveExpiredDataWhenEnterBackground = should == 1 ? YES : NO;
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(set_remove_exporeddata_terminate)(int should){
    [MXLogger shareManager].shouldRemoveExpiredDataWhenTerminate = should == 1 ? YES : NO;
}
BLINGLOG_EXPORT void BLINGLOG_FUNC(set_max_disk_age)(int max_age){
    [MXLogger shareManager].maxDiskAge = [[NSNumber numberWithInt:max_age] integerValue];
}
BLINGLOG_EXPORT void BLINGLOG_FUNC(set_max_disk_size)(uint max_size){
    
    [MXLogger shareManager].maxDiskSize = [[NSNumber numberWithUnsignedInt:max_size] unsignedIntegerValue];
}

BLINGLOG_EXPORT unsigned long BLINGLOG_FUNC(get_log_size)(){
    NSUInteger size = [MXLogger shareManager].logSize;
    
    return size;
}
BLINGLOG_EXPORT int BLINGLOG_FUNC(is_debug_tracking)(){
    BOOL isTracking =  [MXLogger shareManager].isDebugTracking;

    return  isTracking == YES ? 1 : 0;;
}

BLINGLOG_EXPORT const char* BLINGLOG_FUNC(get_diskcache_path)(){
    NSString  * diskCachePath = [MXLogger shareManager].diskCachePath;
    return [diskCachePath UTF8String];
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(set_file_name)(const char* file_name){
    if(file_name == nullptr) return;
    [MXLogger shareManager].fileName = [NSString stringWithUTF8String:file_name];
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(remove_expire_data)(){
    [MXLogger removeExpireData];
}
BLINGLOG_EXPORT void BLINGLOG_FUNC(remove_all)(){
    [MXLogger removeAll];
}


BLINGLOG_EXPORT void BLINGLOG_FUNC(set_storage_policy)(const char* policy){
    if(policy == nullptr) return;
    
    [MXLogger shareManager].storagePolicy = [NSString stringWithUTF8String:policy];
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(set_file_pattern)(const char*pattern){
    if(pattern == nullptr) return;
    
    [MXLogger shareManager].filePattern = [NSString stringWithUTF8String:pattern];
  
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(log)(const char* name, int lvl,const char* msg,const char* tag){
    
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
    // flutter 屏蔽了 stdout和stderr 无法输出到控制台
    [MXLogger logFile:_name level:[[NSNumber numberWithInt:lvl] integerValue] msg:[NSString stringWithUTF8String:msg] tag:_tag];
}

BLINGLOG_EXPORT void BLINGLOG_FUNC(async_log_file)(const char* name, int lvl,const char* msg,const char* tag){
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
    [MXLogger asyncLogFile:_name level:lvl msg:[NSString stringWithUTF8String:msg] tag:_tag];
}


BLINGLOG_EXPORT void BLINGLOG_FUNC(sync_log_file)(const char* name, int lvl,const char* msg,const char* tag){
    NSString * _name = name == nullptr ? NULL : [NSString stringWithUTF8String:name];
    NSString * _tag = tag == nullptr ? NULL : [NSString stringWithUTF8String:tag];
    
    [MXLogger syncLogFile:_name level:lvl msg:[NSString stringWithUTF8String:msg] tag:_tag];
}




@interface BlingLoggerDummy : NSObject
@end

@implementation BlingLoggerDummy
@end

