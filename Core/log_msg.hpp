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
    log_msg(level::level_enum level, string name,string tag,string msg,bool is_main_thread);
    string name;
    
    string tag;
    
    size_t thread_id{0};
    
    bool is_main_thread;
    
    string msg;
    
    chrono::system_clock::time_point time;
    
    level::level_enum level{level::debug};

};

}
}

#endif /* log_msg_hpp */
