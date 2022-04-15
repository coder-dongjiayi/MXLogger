//
//  log_msg.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "log_msg.hpp"
#include "logger_os.hpp"
namespace mxlogger{
namespace details{

log_msg::log_msg(level::level_enum _level, string_view _name,string_view _tag,string_view _msg,bool _is_main_thread):level(_level),name(_name),tag(_tag),msg(_msg),is_main_thread(_is_main_thread),time(std::chrono::system_clock::now()),thread_id(logger_os::thread_id()) {
    
}
};

};
