//
//  logger.cpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#include "logger.hpp"
#include "sinks.h"
namespace blinglog {



void logger::log(level::level_enum lvl,string_view_t prefix,string_view_t msg,string_view_t tag,bool is_main_thread){
    
    
    details::log_msg log_msg(prefix,lvl,msg,tag,is_main_thread);

    
    bool log_enabled = should_log(lvl);
    
    
    log_it_(log_enabled,log_msg);
}

void logger::log_it_(bool log_enabled, const details::log_msg &msg){
    if(log_enabled == false) return;
    
    sink_it_(msg);
}
void logger::set_level(level::level_enum lvl){
    level_.store(lvl);
}

void logger::set_pattern(const std::string &pattern){

    current_sink->set_pattern(pattern);
    
}
bool blinglog::logger::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}

level::level_enum logger:: level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}

std::string logger:: name() const{
    return name_;
}
void logger::flush(){
    
    flush_();
}
void logger::flush_(){

    current_sink->flush();

}

void logger::sink_it_(const details::log_msg &msg){
    
    if(current_sink->should_log(msg.level)){
        current_sink->log(msg);
    }
}
}
