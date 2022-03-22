//
//  log_msg.cpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#include "log_msg.h"
#include <chrono>
#include "logger_os.hpp"
namespace blinglog {
namespace details {


log_msg::log_msg( string_view_t a_prefix, level::level_enum lv, string_view_t msg,string_view_t tag_,bool is_main_thread_)
:log_msg(log_clock::now(),a_prefix,lv,msg,tag_, is_main_thread_)
{
    
   
}


log_msg::log_msg(log_clock::time_point log_time, string_view_t a_prefix, level::level_enum lv, string_view_t msg,string_view_t tag_,bool is_main_thread_)
:time(log_time),
prefix(a_prefix),
payload(msg),
tag(tag_),
level(lv),
thread_id(logger_os::thread_id()),
is_main_thread(is_main_thread_)
{

}

}

}

