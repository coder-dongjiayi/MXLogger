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


    std::string time_str =  mxlogger_helper::micros_datetime(log_msg.time);

    dest.append(time_str);
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
    dest.append(msg.name);
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
