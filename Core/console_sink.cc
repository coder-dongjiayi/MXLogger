//
//  console_sink.cpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#include "console_sink.h"
#include <iostream>
#include "pattern_formatter.hpp"
#include "logger_common.h"
namespace blinglog{
namespace sinks{


void console_sink::log(const details::log_msg &msg)
{
    std::lock_guard<mutex::console_mutex> lock(mutex_t);
    
    
    memory_buf_t formatted;
    
    formatter_ ->format(msg, formatted);
    
    print_range_(formatted, 0, formatted.size());
  
    fflush(target_file_);
}

void console_sink::print_range_(const memory_buf_t &formatted, size_t start, size_t end){
  
    
    fwrite(formatted.data() + start,  sizeof(char), end-start,target_file_);
}

void console_sink::flush(){
    std::lock_guard<mutex::console_mutex> lock(mutex_t);
    fflush(target_file_);
}

void console_sink::set_pattern(const std::string &pattern){
    // 构建fommater
    formatter_ = std::unique_ptr<blinglog::formatter>(new pattern_formatter(pattern));
};

console_sink::console_sink(FILE * target_file):  target_file_(target_file),formatter_(make_unique<pattern_formatter>()){
    
    
    
}


}

}


