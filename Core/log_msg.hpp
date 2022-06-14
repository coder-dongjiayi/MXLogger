//
//  log_msg.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef log_msg_hpp
#define log_msg_hpp

#include <stdio.h>
#include <string>
#include "log_enum.h"
#include <chrono>

using namespace std;
namespace mxlogger {
namespace details{

struct log_msg{
    log_msg() = default;
    ~log_msg() = default;
    log_msg(level::level_enum level, const char* name,const char* tag,const char* msg,bool is_main_thread);
    const char* name;
    
    const char* tag;
    
    size_t thread_id{0};
    
    bool is_main_thread;
    
    const char* msg;
    
    int64_t time_stamp;
 
    std::chrono::system_clock::time_point now_time;
    
    level::level_enum level{level::debug};

};

}
}

#endif /* log_msg_hpp */
