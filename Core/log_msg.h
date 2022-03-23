//
//  log_msg.hpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#pragma once
#include "logger_common.h"
#include <stdio.h>

namespace mxlogger {
namespace details {
struct log_msg{
    
    log_msg() = default;
    
    log_msg(string_view_t prefix,level::level_enum lv,string_view_t msg,string_view_t tag,bool is_main_thread);
    
    log_msg(log_clock::time_point log_time, string_view_t prefix,level::level_enum lv,string_view_t msg,string_view_t tag,bool is_main_thread);

    string_view_t prefix;
    
    string_view_t tag;
    
    size_t thread_id{0};
    
    bool is_main_thread;
    
    log_clock::time_point time;
    
    string_view_t payload;
    
    level::level_enum level{level::debug};
};

}
}
