//
//  log_msg.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "log_msg.hpp"
#include "logger_os.hpp"
#include "mxlogger_helper.hpp"
namespace mxlogger{
namespace details{

log_msg::log_msg(level::level_enum _level, const char* _name,const char* _tag,const char* _msg,bool _is_main_thread):level(_level),name(_name),tag(_tag),msg(_msg),is_main_thread(_is_main_thread),thread_id(logger_os::thread_id()),now_time(std::chrono::system_clock::now())  {
    time_stamp = mxlogger_helper::time_stamp_milliseconds(now_time);
}



}

}
