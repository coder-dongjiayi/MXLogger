//
//  mxlog.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "mxlogger.hpp"

#include <mutex>
#include <unordered_map>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "mmap_sink.hpp"
#include "mxlogger_helper.hpp"
#include "log_msg.hpp"
namespace mxlogger{

std::unordered_map<std::string, mxlogger *> *global_instanceDic_ =  new std::unordered_map<std::string, mxlogger *>;





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
    std::string  directory_s = std::string{directory};
    
    std::string ns_s = std::string{ns};
    
    std::string diskcache_path = directory_s + "/" + ns_s + "/";
    return diskcache_path;
}

mxlogger *mxlogger::initialize_namespace(const char* ns,const char* directory,const char* storage_policy,const char* file_name,const char* cryptKey, const char* iv){
    
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
    
    auto logger = new mxlogger(diskcache_path.c_str(),storage_policy,file_name,cryptKey,iv);
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

mxlogger::mxlogger(const char *diskcache_path,const char* storage_policy,const char* file_name,const char* cryptKey, const char* iv) : diskcache_path_(diskcache_path),storage_policy_(storage_policy),file_name_(file_name){
    
    mmap_sink_ = std::make_shared<sinks::mmap_sink>(diskcache_path,mxlogger_helper::policy_(storage_policy));
   
    mmap_sink_ -> set_custom_filename(file_name);
    
    mmap_sink_ -> init_aescfb(cryptKey, iv);
    
    enable_ = true;
    enable_console_ = false;
    
}

    

mxlogger::~mxlogger(){
    
}

const char* mxlogger::diskcache_path() const{
    return diskcache_path_.c_str();
}

void mxlogger::set_enable(bool enable){
    
    enable_ = enable;
}
void mxlogger::set_enable_console(bool enable){
    enable_console_ = enable;
}
void mxlogger::set_debug(bool enable){
    is_debug_tracking_ = enable;
}

// 设置日志文件最大字节数(byte)
void mxlogger::set_file_max_size(const  long max_size){
    mmap_sink_ -> set_max_disk_size(max_size);
}

// 设置日志文件最大存储时长(s)
void mxlogger::set_file_max_age(const  long max_age){
    mmap_sink_ -> set_max_disk_age(max_age);
}

// 清理过期文件
void mxlogger::remove_expire_data(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> remove_expire_data();
}

//删除所有日志文件
void mxlogger::remove_all(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> remove_all();
}

// 缓存日志文件大小(byte)
long  mxlogger::dir_size(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    return mmap_sink_->dir_size();
}


void mxlogger::set_file_level(int level){
    mmap_sink_ -> set_level(mxlogger_helper::level_(level));
}

void mxlogger::flush(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> flush();
}


void mxlogger::log(int level,const char* name, const char* msg,const char* tag,bool is_main_thread){
    if (enable_ == false) {
        return;
    }
    
    std::lock_guard<std::mutex> lock(logger_mutex);
    
    if (name == nullptr || strcmp(name, "") == 0) {
        name = "mxlogger";
    }
   
    level::level_enum lvl = mxlogger_helper::level_(level);

    details::log_msg log_msg(lvl,name,tag,msg,is_main_thread);
    
    mmap_sink_ -> log(log_msg);
   
    if (enable_console_) {
        
        std::string time = mxlogger_helper::micros_time(log_msg.now_time);
        std::string log = "[" + std::string{name} + "] " + time + "【"+std::string{level_names[level]} + "】" + (tag != nullptr ? "<" + std::string{tag} + ">" : "") + std::string{msg};
        
        printf("%s\n",log.data());
    }

   
}

}
