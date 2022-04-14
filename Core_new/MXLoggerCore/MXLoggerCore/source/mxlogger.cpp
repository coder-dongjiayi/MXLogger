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
namespace mxlogger{
mxlogger::mxlogger(const char* diskcache_path) : diskcache_path_(diskcache_path){
    printf("log 初始化完成:%s\n",diskcache_path_.c_str());
    
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

void mxlogger::set_enable(bool enable){
    
}
void mxlogger::set_console_enable(bool enable){
    
}
void mxlogger::set_file_enable(bool enbale){
    
}
void mxlogger::log(int type, int level,const char* name, const char* msg,const char* tag,bool is_main_thread){
    
    details::log_msg log_msg(level::level_enum::info,name,tag,msg,true);

    console_sink_->log(log_msg);
    
    file_sink_ -> log(log_msg);
    
}

}
