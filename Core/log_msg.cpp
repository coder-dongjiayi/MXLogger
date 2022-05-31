//
//  log_msg.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "log_msg.hpp"
#include "logger_os.hpp"
#include "cJson/cJSON.h"
#include "mxlogger_helper.hpp"
namespace mxlogger{
namespace details{

log_msg::log_msg(level::level_enum _level, string _name,string _tag,string _msg,bool _is_main_thread):level(_level),name(_name),tag(_tag),msg(_msg),is_main_thread(_is_main_thread),time(std::chrono::system_clock::now()),thread_id(logger_os::thread_id()) {
    
    
    std::time_t tt=  std::chrono::system_clock::to_time_t(time);
    
    auto micro = mxlogger_helper::time_fraction<std::chrono::microseconds>(time);
    
   std::string time_str =   mxlogger_helper::string_format("%10d.%06d",tt,micro);
    cJSON * json = cJSON_CreateObject();

    cJSON_AddStringToObject(json, "n", _name.data());
    cJSON_AddStringToObject(json, "a", _tag.data());
    cJSON_AddStringToObject(json, "m", _msg.data());
    cJSON_AddBoolToObject(json, "imt",is_main_thread);
    cJSON_AddNumberToObject(json, "tid", thread_id);
    cJSON_AddNumberToObject(json,"p",_level);
    cJSON_AddStringToObject(json, "s", time_str.data());

    char * jsonchars = cJSON_PrintUnformatted(json);

    cJSON_Delete(json);
    
    strcat(jsonchars, "\n");
    json_string = string{jsonchars};
}



}

}
