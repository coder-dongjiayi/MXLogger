//
//  yjdlog.cpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#include "sinks.h"
void blinglog::sinks::sink::set_level(level::level_enum log_level){
     level_.store(log_level,std::memory_order_relaxed);
}

bool blinglog::sinks::sink::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}


level::level_enum   blinglog::sinks::sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}

