//
//  mxlog.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "mxlogger.hpp"
#include "log_msg.hpp"
#include "console_sink.hpp"
#include "file_sink.hpp"
#include "mx_file.hpp"
#include <mutex>
#include <unordered_map>
#include "mxlogger_helper.hpp"
#ifdef  __APPLE__
#include <sys/sysctl.h>
#endif
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "cJson/cJSON.h"
#include "mmap_sink.hpp"
#include "mxlogger_file_util.hpp"
namespace mxlogger{

std::unordered_map<string, mxlogger *> *global_instanceDic_ =  new unordered_map<string, mxlogger *>;


static level::level_enum level_(int lvl){
  
    switch (lvl) {
        case 0:
            return level::level_enum::debug;
        case 1:
            return level::level_enum::info;
        case 2:
            return level::level_enum::warn;
        case 3:
            return level::level_enum::error;
        case 4:
            return level::level_enum::fatal;
            
        default:
            return level::level_enum::debug;
    }
    
}
static policy::storage_policy policy_(const char* storage_policy){
    
    if (strcmp(storage_policy, "yyyy_MM") == 0) {
        return policy::storage_policy::yyyy_MM;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd") == 0) {
        return policy::storage_policy::yyyy_MM_dd;
    }
    if (strcmp(storage_policy, "yyyy_ww") == 0) {
        return policy::storage_policy::yyyy_ww;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd_HH") == 0) {
        return policy::storage_policy::yyyy_MM_dd_HH;;
    }
    return policy::storage_policy::yyyy_MM_dd;
}


/// 暂时先返回true
static bool is_debuging_() {
    return true;
    
//#ifdef __ANDROID__
//
//   return true;
//
//#elif __APPLE__
//    struct kinfo_proc procInfo;
//    size_t structSize = sizeof(procInfo);
//    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
//
//    if(sysctl(mib, sizeof(mib)/sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0)
//    {
//        strerror(errno);
//        return false;
//    }
//
//    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
//
//#endif
//    return false;
}


 std::string mxlogger::md5(const char* ns,const char* directory){
     
     std::string diskcache_path = get_diskcache_path_(ns,directory);
     std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);

     return map_key;
}



std::string mxlogger::get_diskcache_path_(const char* ns,const char* directory){
    if (directory == nullptr) {
        return std::string{nullptr};
    }
    if (ns == nullptr) {
        ns = "default";
    }
    std::string  directory_s = string{directory};
    
    std::string ns_s = string{ns};
    
    std::string diskcache_path = directory_s + "/" + ns_s + "/";
    return diskcache_path;
}

mxlogger *mxlogger::initialize_namespace(const char* ns,const char* directory){
    
    std::string diskcache_path = get_diskcache_path_(ns,directory);
    if (diskcache_path.data() == nullptr) {
        return nullptr;
    }
    
    std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);
    
    auto itr = global_instanceDic_ -> find(map_key);
    if (itr != global_instanceDic_ -> end()) {
        mxlogger * logger = itr -> second;
        return logger;
    }
    
    auto logger = new mxlogger(diskcache_path.c_str());
    logger -> map_key = map_key;
    (*global_instanceDic_)[map_key] = logger;
    return logger;
}

void mxlogger::delete_namespace(const char* ns,const char* directory){
    std::string diskcache_path = get_diskcache_path_(ns,directory);
    if (diskcache_path.data() == nullptr) {
        return;
    }
    std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);
    for (auto &pair : *global_instanceDic_) {
         std::string key = pair.first;
        if (key == map_key) {
            delete pair.second;
            pair.second = nullptr;
        }
    }
}
void mxlogger::destroy(){
    
    for (auto &pair : *global_instanceDic_) {
        mxlogger *logger = pair.second;
        delete logger;
        pair.second = nullptr;
    }
  
    
}

mxlogger::mxlogger(const char* diskcache_path) : diskcache_path_(diskcache_path){
    
    
    console_sink_ = std::make_shared<sinks::console_sink>(stdout);
    console_sink_ -> set_pattern("[%d][%p]%m");
    console_sink_ -> set_level(level::level_enum::debug);
    
    auto file =   std::make_shared<details::mx_file>();
    
    file_sink_ = std::make_shared<sinks::file_sink>(std::move(file));
    
    file_sink_ -> mxfile -> set_dir(diskcache_path);
    
    file_sink_ -> set_level(level::level_enum::info);
    
    mmap_sink_ = std::make_shared<sinks::mmap_sink>(diskcache_path,policy::storage_policy::yyyy_MM_dd);
    
    is_debug_tracking_ = is_debuging_();
    
    enable_ = true;
    console_enable_ = is_debug_tracking_;
    file_enable_ = true;
    
}

mxlogger::~mxlogger(){
    
}

const char* mxlogger::diskcache_path() const{
    return diskcache_path_.c_str();
}
const bool mxlogger::is_debug_tracking(){
    return is_debug_tracking_;
}
void mxlogger::set_enable(bool enable){
    
    enable_ = enable;
}
void mxlogger::set_console_enable(bool enable){
    console_enable_ = enable;
}
void mxlogger::set_file_enable(bool enable){
    file_enable_ = enable;
    
}
void mxlogger::set_file_policy(const char* policy){
    
    file_sink_->set_policy(policy_(policy));
}


void mxlogger::set_file_name(const char* filename){
    file_sink_->set_filename(filename);
}

void mxlogger::set_file_header(const char* header){
    
    std::lock_guard<std::mutex> lock(logger_mutex);
    
    cJSON * json = cJSON_CreateObject();
    cJSON_AddStringToObject(json, "header", header);
    char * json_chars =  cJSON_PrintUnformatted(json);
    
    file_sink_->mxfile->set_header(json_chars);
}

// 设置日志文件最大字节数(byte)
void mxlogger::set_file_max_size(const  long max_size){
    file_sink_->mxfile->set_max_disk_size(max_size);
}

// 设置日志文件最大存储时长(s)
void mxlogger::set_file_max_age(const  long max_age){
    file_sink_->mxfile->set_max_disk_age(max_age);
}

// 清理过期文件
void mxlogger::remove_expire_data(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    file_sink_->mxfile->remove_expire_data();
}

//删除所有日志文件
void mxlogger::remove_all(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    file_sink_->mxfile->remove_all();
}

// 缓存日志文件大小(byte)
long  mxlogger::dir_size(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    return file_sink_->mxfile->dir_size();
}
void mxlogger::set_console_level(int level){
    console_sink_ -> set_level(level_(level));
}

void mxlogger::set_file_level(int level){
    file_sink_ -> set_level(level_(level));
}

void mxlogger::set_pattern(const char * pattern){
    console_sink_ -> set_pattern(pattern);
}


void mxlogger::log(int type, int level,const char* name, const char* msg,const char* tag,bool is_main_thread){
    if (enable_ == false) {
        return;
    }
    std::lock_guard<std::mutex> lock(logger_mutex);
    
    level::level_enum lvl = level_(level);
    
    string _name = name == nullptr ? string{"mxlogger"} : name;
    
    string _tag = tag == nullptr ? string{} : string{tag};
    
    string _msg = msg == nullptr ? string{"nullptr"} : msg;
    
    details::log_msg log_msg(lvl,_name,_tag,_msg,is_main_thread);
 
 
   if (console_enable_ == true) {
        console_sink_->log(log_msg);
    }

    if (file_enable_ == true) {
        mmap_sink_ -> log(log_msg);
       // file_sink_ -> log(log_msg);
    }
   
}

}
