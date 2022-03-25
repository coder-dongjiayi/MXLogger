//
//  pattern_formatter.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#include "pattern_formatter.hpp"
#include "logger_common.h"

namespace mxlogger {

pattern_formatter::pattern_formatter():pattern_formatter("[%d][%p]%m"){}

pattern_formatter::pattern_formatter(std::string pattern) : pattern_(std::move(pattern)){
    
    compile_pattern_(pattern_);
    
}

void pattern_formatter::compile_pattern_(const std::string pattern){
    auto end =  pattern.end();
    std::unique_ptr<details::aggregate_formatter> user_chars;
    
    formatters_.push_back(make_unique<details::prefix_formatter>());
    
    for (auto it = pattern.begin(); it != end; it++ ) {
     
        if(*it == '%'){
          
            if (user_chars) {
                formatters_.push_back(std::move(user_chars));
            }
            
            if(end == it) break;
            it = it + 1;
            handle_flag_(*it);
        }else{
            if (!user_chars) {
                user_chars = make_unique<details::aggregate_formatter>();
            }
            user_chars->add_char(*it);
        }
       
    }
    
    if (user_chars) {
        formatters_.push_back(std::move(user_chars));
    }
}

void pattern_formatter:: handle_flag_(char flag){
    
  
    
    switch (flag) {
       
        case ('d'):
            formatters_.push_back(make_unique<details::time_formatter>());
            break;
        case ('p'):
            formatters_.push_back(make_unique<details::level_formatter>());
            break;
        case ('m'):
            formatters_.push_back(make_unique<details::tag_formatter>());
            formatters_.push_back(make_unique<details::message_formatter>());
            break;
        case ('t'):
            formatters_.push_back(make_unique<details::thread_formatter>());
            break;
        default:
            break;
    }
}

void pattern_formatter::format(const details::log_msg &log_msg, memory_buf_t &dest){
   

    std::tm ltm =  fmt_lib::localtime(log_clock::to_time_t(log_msg.time));
    
    for (auto &f : formatters_) {
    
       
        f->format(log_msg, ltm, dest);
    }

    details::fmt_helper::append_string_view(default_eol, dest);


}


}
