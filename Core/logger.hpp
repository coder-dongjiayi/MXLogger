//
//  logger.hpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#pragma once

#include <stdio.h>
#include <string>
#include <vector>
#include <unordered_map>
#include "logger_common.h"
#include "log_msg.h"

namespace mxlogger {
class logger{
public:
   
    virtual ~logger() = default;
    

    logger(std::string name,sink_ptr single_sink) : name_(std::move(name)),current_sink(std::move(single_sink)){}

    void log(level::level_enum lvl,string_view_t prefix,string_view_t msg,string_view_t tag,bool is_main_thread);
    
    void set_level(level::level_enum lvl);
    
    void set_pattern(const std::string &pattern);
    
    bool should_log(level::level_enum mesg_level);
    
    
    
    level::level_enum level() const;
    
    std::string name() const;
   

    sink_ptr current_sink;
    
protected:
    
    virtual void sink_it_(const details::log_msg &msg);
    virtual void flush();
    
    void log_it_(bool log_enabled,const details::log_msg &msg);
    
    level_t level_{level::debug};
  
    std::string name_;
    
   
    
private:
    virtual void flush_();
    
};
}

