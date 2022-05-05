//
//  file_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/14.
//

#include "file_sink.hpp"
#include "cJson/cJSON.h"
#include "mxlogger_helper.hpp"
namespace mxlogger{

namespace sinks{
void file_sink::log(const details::log_msg &msg){
    if (should_log(msg.level) == false) return;
    
    std::string time_str =  mxlogger_helper::micros_datetime(msg.time);
    cJSON * json = cJSON_CreateObject();

    cJSON_AddStringToObject(json, "name", msg.name.data());
    cJSON_AddStringToObject(json, "tag", msg.tag.data());
    cJSON_AddStringToObject(json, "msg", msg.msg.data());
    cJSON_AddBoolToObject(json, "is_main_thread", msg.is_main_thread);
    cJSON_AddNumberToObject(json, "thread_id", msg.thread_id);
    cJSON_AddNumberToObject(json,"level",msg.level);
    cJSON_AddStringToObject(json, "time", time_str.data());

    char * json_string = cJSON_PrintUnformatted(json);

    strcat(json_string, "\n");

    mxfile -> write(json_string, file_appender_.calc_filename());

    mxfile-> flush();
    
}

void file_sink::set_pattern(const std::string &pattern){
    formatter_ =  std::unique_ptr<mxlogger::pattern_formatter>(new mxlogger::pattern_formatter(pattern));
}

void file_sink::set_policy(policy::storage_policy policy){
    file_appender_.set_policy(policy);
}
void file_sink::set_filename(const std::string filename){
    file_appender_.set_filename(filename);
}



void file_sink::flush() {
    mxfile -> flush();
}
};

};
