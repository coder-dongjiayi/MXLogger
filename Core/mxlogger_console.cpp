//
//  mxloger_console.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2023/2/9.
//

#include "mxlogger_console.hpp"
#include <sstream>
#include <iomanip>
#include "log_enum.h"
#include "mxlogger_helper.hpp"
#ifdef  __ANDROID__
#include <android/log.h>
#endif
#include "json/cJSON.h"
namespace mxlogger{

void mxlogger_console::print(const details::log_msg& msg){

    std::string console = gen_console_str(msg);
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
        console.append("\0");
            __android_log_write(priority,  msg.tag, console.c_str());
    #elif __APPLE__
    
    printf("%s", console.data());
    #endif
   
}

std::string mxlogger_console:: gen_console_str(const details::log_msg& msg){
    
    
    constexpr auto width = 80U;
    
    std::string time = mxlogger_helper::micros_datetime(msg.now_time);
    
    std::basic_ostringstream<char> stream;
    
    
    std::string string_msg = {msg.msg};
    cJSON * jsonItem = cJSON_Parse(msg.msg);
    if(jsonItem != nullptr){
        string_msg = cJSON_Print(jsonItem);
    }
    cJSON_free(jsonItem);
    
    std::string thread =  std::to_string(msg.thread_id)  + ":"+ (msg.is_main_thread == true ? "main" : "child");
    
    std::string level = std::string{level_names[msg.level]};
  

    stream << std::endl;
    
    
    for (size_t i = 0; i != width; ++i)
    {
        if(i == width / 2){
            stream << "MXLogger";
        }
            
        stream << "-";
    }
    
    stream << std::endl;
    
    // center

    stream << "time : " << time <<" [" + thread + "]" << endl;
    
    stream << "level: " + level  << std::endl;
    
    stream << "name : " + std::string{msg.name} <<std::endl;
   
    if(msg.tag != nullptr){
        stream << "tags : " + std::string{msg.tag} << std::endl;
    }
   
    stream  << "msg  : " <<string_msg << std::endl;
   
    
    // bottom
    for (size_t i = 0; i != (width + 8); ++i)
    {
        stream << "-";
    }
    stream << std::endl;
    return stream.str();
}


}
