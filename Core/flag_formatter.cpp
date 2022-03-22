//
//  flag_formatter.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#include "flag_formatter.hpp"
#include <chrono>
#include <ctime>
#include "fmt_helper.h"
namespace blinglog {
namespace details{

// [2022-03-02-16:49:57.912]
void time_formatter::format(const details::log_msg &log_msg, const std::tm &tm_time,memory_buf_t &dest){
   
    cached_datetime_.clear();
    
    using std::chrono:: milliseconds;
    fmt_helper::append_int(tm_time.tm_year + 1900, cached_datetime_);
    cached_datetime_.push_back('-');
    fmt_helper::pad2(tm_time.tm_mon + 1, cached_datetime_);
    cached_datetime_.push_back('-');
    fmt_helper::pad2(tm_time.tm_mday, cached_datetime_);
    cached_datetime_.push_back(' ');
    fmt_helper::pad2(tm_time.tm_hour, cached_datetime_);
    cached_datetime_.push_back(':');
    fmt_helper::pad2(tm_time.tm_min, cached_datetime_);
    cached_datetime_.push_back(':');
    fmt_helper::pad2(tm_time.tm_sec, cached_datetime_);
    cached_datetime_.push_back('.');
    auto micro = fmt_helper::time_fraction<std::chrono::microseconds>(log_msg.time);

    fmt_helper::pad3(static_cast<uint32_t>(micro.count()), cached_datetime_);


    dest.append(cached_datetime_.begin(), cached_datetime_.end());
}


void level_formatter::format(const details::log_msg &log_msg, const std::tm &tm_time, memory_buf_t &dest){
    
    string_view_t level_name{level_names[log_msg.level]};
    
    fmt_helper::append_string_view(level_name, dest);
}

void message_formatter::format(const details::log_msg &log_msg, const std::tm &tm_time, memory_buf_t &dest){
    
    fmt_helper::append_string_view(log_msg.payload, dest);
}
void aggregate_formatter::format(const details::log_msg &log_msg, const std::tm &tm_time, memory_buf_t &dest){
    
    fmt_helper::append_string_view(str_, dest);
}

void tag_formatter:: format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest){
    if(msg.tag.data() == nullptr || msg.tag == "") return;
    
    fmt_helper::append_string_view("{",dest);
    fmt_helper::append_string_view(msg.tag, dest);
    fmt_helper::append_string_view("}",dest);
}

void prefix_formatter:: format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest){
    if(msg.prefix.data() == nullptr || msg.prefix == "") return;
    
    fmt_helper::append_string_view("[",dest);
    fmt_helper::append_string_view(msg.prefix, dest);
    fmt_helper::append_string_view("]",dest);
    fmt_helper::append_string_view(":",dest);
}
void thread_formatter:: format(const details::log_msg &msg, const std::tm &tm_time, memory_buf_t &dest){
  
     

    fmt_helper::append_string_view( std::to_string(msg.thread_id), dest);
    if (msg.is_main_thread == true) {
        fmt_helper::append_string_view(":main",dest);
    }else{
        fmt_helper::append_string_view(":child",dest);
    }
   
   
   
   
}


}

}
