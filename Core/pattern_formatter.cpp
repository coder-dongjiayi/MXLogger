//
//  pattern_formatter.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "pattern_formatter.hpp"

namespace mxlogger{

pattern_formatter::pattern_formatter(const std::string &pattern):pattern_(pattern){
    compile_pattern_(pattern);
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

void pattern_formatter::format(const details::log_msg &msg, string &dest){
  
    for (auto &f : formatters_) {
        f -> format(msg, dest);
        
    }
    
    dest.append("\n");
    
}
}
