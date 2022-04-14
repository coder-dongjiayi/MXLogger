//
//  sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "sink.hpp"
namespace mxlogger{
namespace sinks{
void sink::set_level(level::level_enum log_level){
     level_.store(log_level,std::memory_order_relaxed);
}

bool sink::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}


level::level_enum  sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}
};
}
