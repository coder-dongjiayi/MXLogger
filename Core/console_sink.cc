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
#ifdef  __ANDROID__
#include <android/log.h>
#endif

namespace mxlogger{
namespace sinks{


void console_sink::log(const details::log_msg &msg)
{
    std::lock_guard<mutex::console_mutex> lock(mutex_t);


    memory_buf_t formatted;
  
    formatter_ ->format(msg, formatted);

#ifdef __ANDROID__
    android_LogPriority priority;
    switch (msg.level) {
        case level::level_enum::debug:
            priority = ANDROID_LOG_DEBUG;
            break;
        case level::level_enum::info:
            priority = ANDROID_LOG_INFO;
            break;
        case level::level_enum::warn:
            priority = ANDROID_LOG_WARN;
            break;
        case level::level_enum::error:
            priority = ANDROID_LOG_ERROR;
            break;
        case level::level_enum::fatal:
            priority = ANDROID_LOG_FATAL;
            break;
        default:
            priority = ANDROID_LOG_DEBUG;
            break;

    }
    formatted.push_back('\0');

    const char *msg_output = formatted.data();

    __android_log_write(priority, msg.tag.data(), msg_output);

#elif __APPLE__
    print_range_(formatted, 0, formatted.size());

    fflush(target_file_);
#endif


}

void console_sink::print_range_(const memory_buf_t &formatted, size_t start, size_t end){

    const char * msg = formatted.data();
    
    fwrite(msg,  sizeof(char), end-start,target_file_);

    

}

void console_sink::flush(){
    std::lock_guard<mutex::console_mutex> lock(mutex_t);
    fflush(target_file_);
}

void console_sink::set_pattern(const std::string &pattern){
    // 构建fommater
    formatter_ = std::unique_ptr<mxlogger::formatter>(new pattern_formatter(pattern));
};

console_sink::console_sink(FILE * target_file):  target_file_(target_file),formatter_(make_unique<pattern_formatter>()){

    
    
}


}

}


