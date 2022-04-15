//
//  flag_formatter.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#include "flag_formatter.hpp"
#include "mxlogger_helper.hpp"

static const char *level_names[]{"DEBUG","INFO","WARN","ERROR","FATAL"};
namespace mxlogger {
namespace details{

// [2022-03-02-16:49:57.912]
void time_formatter::format(const details::log_msg &log_msg, string &dest){
    cached_datetime_.clear();
    
    std::tm tm_time = mxlogger_helper::localtime(std::chrono::system_clock::to_time_t(log_msg.time));
    
    auto micro = mxlogger_helper::time_fraction<std::chrono::microseconds>(log_msg.time);
    
    using std::chrono:: milliseconds;
    cached_datetime_ =  mxlogger_helper::string_format("%04d-%02d-%02d %02d:%02d:%02d.%06d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, tm_time.tm_hour,tm_time.tm_min,tm_time.tm_sec,micro);
    
   
    dest.append(cached_datetime_);
}


void level_formatter::format(const details::log_msg &log_msg, string &dest){
    
    string level_name{level_names[log_msg.level]};
    dest.append(level_name);
}

void message_formatter::format(const details::log_msg &log_msg, string &dest){
    
    dest.append(log_msg.msg);
}
void aggregate_formatter::format(const details::log_msg &log_msg, string &dest){
    
    dest.append(str_);
}

void tag_formatter:: format(const details::log_msg &msg,  string &dest){
   
    if(msg.tag.data() == nullptr || msg.tag == "") return;

    dest.append("<");
    dest.append(msg.tag);
    dest.append(">");
   
}

void prefix_formatter:: format(const details::log_msg &msg, string &dest){
    
    dest.append("[");

    if(msg.name.data() == nullptr || msg.name == "") {
        dest.append("mxlogger");
       
    }else{
        dest.append(msg.name);
        
    }
    dest.append("]");
    dest.append(":");
    

    
}
void thread_formatter:: format(const details::log_msg &msg, string &dest){
  
    dest.append(std::to_string(msg.thread_id));
    
    if (msg.is_main_thread == true) {
        dest.append(":main");

    }else{
        dest.append(":child");
  
    }
   

   
   
   
}


}

}
