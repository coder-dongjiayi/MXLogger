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

namespace mxlogger{

namespace mutex{

struct console_mutex{
    using mutex_t = std::mutex;
    static mutex_t &mutex(){
        static mutex_t s_mutex;
        return s_mutex;
    }
};
}

using mutex_t = typename mutex::console_mutex;

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



mxlogger::mxlogger(const char* diskcache_path) : diskcache_path_(diskcache_path){
    
    enable_ = true;
    console_enable_ = true;
    file_enable_ = true;
    
    console_sink_ = std::make_shared<sinks::console_sink>(stdout);
    console_sink_ -> set_pattern("[%d][%p]%m");
    console_sink_ -> set_level(level::level_enum::debug);
    
    auto file =   std::make_shared<details::mx_file>();
    
    file_sink_ = std::make_shared<sinks::file_sink>(std::move(file));
    
    file_sink_ -> mxfile -> set_dir(diskcache_path);
    
    file_sink_ -> set_pattern("[%d][%t][%p]%m");
    
    file_sink_ -> set_level(level::level_enum::info);
}

mxlogger::~mxlogger(){
    printf("log 已经释放\n");
}

const char* mxlogger::diskcache_path() const{
    return diskcache_path_.c_str();
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
    
    file_sink_->mxfile->set_header(header);
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
    std::lock_guard<std::mutex> lock(mutex_t);
    file_sink_->mxfile->remove_expire_data();
}

//删除所有日志文件
void mxlogger::remove_all(){
    std::lock_guard<std::mutex> lock(mutex_t);
    file_sink_->mxfile->remove_all();
}

// 缓存日志文件大小(byte)
long  mxlogger::file_size(){
    std::lock_guard<std::mutex> lock(mutex_t);
    return file_sink_->mxfile->file_size();
}
void mxlogger::set_console_level(int level){
    console_sink_ -> set_level(level_(level));
}

void mxlogger::set_file_level(int level){
    file_sink_ -> set_level(level_(level));
}

void mxlogger::set_console_pattern(const char * pattern){
    console_sink_ -> set_pattern(pattern);
}

void mxlogger::set_file_pattern(const char * pattern){
    file_sink_ -> set_pattern(pattern);
}

void mxlogger::log(int type, int level,const char* name, const char* msg,const char* tag,bool is_main_thread){
    if (enable_ == false) {
        return;
    }
    std::lock_guard<std::mutex> lock(mutex_t);
    
    level::level_enum lvl = level_(level);
    
    details::log_msg log_msg(lvl,name,tag,msg,is_main_thread);

    if (console_enable_ == true) {
        console_sink_->log(log_msg);
    }
   
    if (file_enable_ == true) {
        file_sink_ -> log(log_msg);
    }
   
}

}
