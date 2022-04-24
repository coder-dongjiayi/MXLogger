//
//  console_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "console_sink.hpp"
#ifdef  __ANDROID__
#include <android/log.h>
#endif
namespace mxlogger{

namespace sinks{

console_sink::console_sink(FILE * target_file):  target_file_(target_file){

}
void console_sink::log(const details::log_msg &msg)
{
 
    if (should_log(msg.level) == false) return;
   
    std:: string formatted;
    
    formatter_ -> format(msg, formatted);

    
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
    formatted.append("\0");

    const char *msg_output = formatted.data();

    __android_log_write(priority, msg.tag.data(), msg_output);

#elif __APPLE__
    size_t msg_size = formatted.size();
    std::fwrite(formatted.data(), sizeof(char), msg_size, target_file_);
 
    fflush(target_file_);
#endif
   
    
}

void console_sink::flush(){
  
    fflush(target_file_);
}


void console_sink::set_pattern(const std::string &pattern){
   
   formatter_ =  std::unique_ptr<mxlogger::pattern_formatter>(new mxlogger::pattern_formatter(pattern));
};

};
};
