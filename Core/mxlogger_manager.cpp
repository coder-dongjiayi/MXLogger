//
//  logger_manager.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/8.
//

#include "mxlogger_manager.hpp"
#include "console_sink.h"
#include "file_sink.hpp"
#include "thread_pool.hpp"
#ifdef  __APPLE__
#include <sys/sysctl.h>
#endif

#include <unistd.h>
namespace mxlogger{



static bool is_debuging_() {
#ifdef __ANDROID__
    const char* filename = "/proc/self/status";
    int fd = open(filename, O_RDONLY);
    if(fd < 0)
    {
        return false;
    }

    char buffer[1000];
    ssize_t bytesRead = read(fd, buffer, sizeof(buffer) - 1);
    close(fd);
    if(bytesRead <= 0)
    {
        return false;
    }

    buffer[bytesRead] = 0;
    const char tracerPidText[] = "TracerPid:";
    const char* tracerPointer = strstr(buffer, tracerPidText);
    if(tracerPointer == NULL)
    {
        return false;
    }

    tracerPointer += sizeof(tracerPidText);
    return atoi(tracerPointer) > 0;
#elif __APPLE__
    struct kinfo_proc procInfo;
    size_t structSize = sizeof(procInfo);
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    
    if(sysctl(mib, sizeof(mib)/sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0)
    {
        strerror(errno);
        return false;
    }
    
    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
#else
    return false;
#endif
}

mxlogger_manager::mxlogger_manager():enable_(true),console_enable_(true),file_enable_(true){
    auto console_sink = std::make_shared<mxlogger::sinks::console_sink>(stdout);

    console_sink->set_pattern("[%d][%p]%m");
    
    auto console_logger = std::make_shared<mxlogger::logger>("console_logger",std::move(console_sink));

    console_logger->set_level(level::level_enum::debug);

    console_logger_ = std::move(console_logger);
    
    tp_ = std::make_shared<thread_pool>(8192, 1U);
    
    
    auto async_file_sink  = std::make_shared<mxlogger::sinks::file_sink>();
    async_file_sink -> set_pattern("[%d][%t][%p]%m");
  
    
    auto async_file_logger = std::make_shared<mxlogger::async_logger>("async_logger",std::move(async_file_sink),tp_);
    async_file_logger -> set_level(level::level_enum::info);
    
    async_file_logger_ = std::move(async_file_logger);
    
    
    auto sync_file_sink  = std::make_shared<mxlogger::sinks::file_sink>();
    sync_file_sink -> set_pattern("[%d][%t][%p]%m");
  
    
    auto sync_file_logger = std::make_shared<mxlogger::logger>("async_logger",std::move(sync_file_sink));
    sync_file_logger -> set_level(level::level_enum::info);
    
    sync_file_logger_ = std::move(sync_file_logger);
    
    
    is_async_ = true;
    debug_traceing_ = is_debuging_();
    
    if (!debug_traceing_) {
        console_enable_ = false;
    }

    

}
mxlogger_manager::~mxlogger_manager(){
    
}

bool mxlogger_manager::is_debuging() const{
  
    return debug_traceing_;
}

void mxlogger_manager::set_enable(const bool enable){
    enable_ = enable;
}

void mxlogger_manager::set_file_name(const char* filename){
   auto async_sink =  dynamic_cast<sinks::file_sink*>((async_file_logger_->current_sink).get());
   auto sync_sink =  dynamic_cast<sinks::file_sink*>((sync_file_logger_->current_sink).get());
    
    async_sink -> set_file_name(filename);
    sync_sink -> set_file_name(filename);
}

void mxlogger_manager::set_file_policy(policy::storage_policy policy){
    auto async_sink =  dynamic_cast<sinks::file_sink*>((async_file_logger_->current_sink).get());
    auto sync_sink =  dynamic_cast<sinks::file_sink*>((sync_file_logger_->current_sink).get());
    sync_sink -> set_file_policy(policy);
    async_sink -> set_file_policy(policy);
}

void mxlogger_manager::set_file_header(const char* header){
    if (header == nullptr) {
        return;
    }

    async_file_sink_() -> set_file_header(header);
    sync_file_sink_() -> set_file_header(header);
    
}
long long mxlogger_manager::file_size(){
 
    return sync_file_sink_() -> file_size();
}
void mxlogger_manager::set_file_dir(const std::string &filedir){
  
    async_file_sink_() -> set_filedir(filedir);
    sync_file_sink_() -> set_filedir(filedir);
}
void mxlogger_manager::set_file_levle(level::level_enum lvl){

    async_file_sink_() -> set_level(lvl);
    sync_file_sink_() -> set_level(lvl);
}

void mxlogger_manager::set_console_levle(level::level_enum lvl){
    
    console_logger_ -> set_level(lvl);
}
void mxlogger_manager::set_console_pattern(const std::string &pattern){
    console_logger_ -> set_pattern(pattern);
}

void mxlogger_manager::set_file_pattern(const std::string &pattern){
 
    sync_file_sink_() -> set_pattern(pattern);
    async_file_sink_() -> set_pattern(pattern);

}
void mxlogger_manager::remove_expire_data(){

    sync_file_sink_() -> remove_expire_data();
}
void mxlogger_manager::remove_all(){
  
    sync_file_sink_() -> remove_all();
}
void mxlogger_manager::set_file_max_size(const long long max_size){
   
    
    sync_file_sink_()->set_file_max_disk_size(max_size);
    async_file_sink_()->set_file_max_disk_size(max_size);
}


void mxlogger_manager::set_file_max_age(const long long max_age){
   
    
    sync_file_sink_()->set_file_max_disk_age(max_age);
    async_file_sink_()->set_file_max_disk_age(max_age);
}

void mxlogger_manager::set_console_enable(const bool enable){
    console_enable_ = enable;
}

void mxlogger_manager::set_file_enable(const bool enable){
    file_enable_ = enable;
}
void mxlogger_manager::log_all(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    log_it_(log_type::all, lvl,name, msg, tag,is_main_thread);
}
void mxlogger_manager::log(log_type type,level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    log_it_(type, lvl,name, msg, tag,is_main_thread);
}
void mxlogger_manager::set_file_async(bool is_async){
    is_async_ = is_async;
}

void mxlogger_manager::log_console_(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    if (console_enable_ == false) {
        return;
    }
    string_view_t name_ =  name == nullptr ? string_view_t{} : name;
    
    
    console_logger_ -> log(lvl,name_, msg == nullptr ?  string_view_t("nullptr") : msg,  tag == nullptr ? string_view_t{} : tag,is_main_thread);

}

void mxlogger_manager::log_async_file(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    if (file_enable_ == false) {
        return;
    }
    string_view_t name_ =  name == nullptr ? string_view_t{} : name;
    async_file_logger_ -> log(lvl,name_, msg == nullptr ?  string_view_t("nullptr") : msg,  tag == nullptr ? string_view_t{} : tag,is_main_thread);
}

void mxlogger_manager::log_sync_file(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    if (file_enable_ == false) {
        return;
    }
    string_view_t name_ =  name == nullptr ? string_view_t{} : name;
    sync_file_logger_ -> log(lvl,name_, msg == nullptr ?  string_view_t("nullptr") : msg,  tag == nullptr ? string_view_t{} : tag,is_main_thread);
}

void mxlogger_manager::log_file_(level::level_enum lvl, const char* name,const char* msg, const char* tag,bool is_main_thread){
    
   
    if (is_async_ == false) {
        log_sync_file(lvl, name, msg, tag, is_main_thread);
    }else{
        log_async_file(lvl, name, msg, tag, is_main_thread);
    }
  
   
    
}

void mxlogger_manager::log_it_(log_type type,level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread){
    if (enable_ == false) {
        return;
    }
    if (type == log_type::console) {
        log_console_(lvl,name, msg, tag,is_main_thread);
    }
    if (type == log_type::file) {
        log_file_(lvl,name, msg, tag,is_main_thread);
    }
    
    if (type == log_type::all) {
        log_console_(lvl, name,msg, tag,is_main_thread);
        log_file_(lvl,name, msg, tag,is_main_thread);
    }
}
inline sinks::file_sink *mxlogger_manager::async_file_sink_(){
    auto async_sink =  dynamic_cast<sinks::file_sink*>((async_file_logger_->current_sink).get());
    return async_sink;
    
}
inline sinks::file_sink *mxlogger_manager::sync_file_sink_(){
    auto sync_sink =  dynamic_cast<sinks::file_sink*>((sync_file_logger_->current_sink).get());
    return sync_sink;
}

mxlogger_manager &mxlogger_manager:: instance(){
    static mxlogger_manager s_manager;
    return  s_manager;
}

}