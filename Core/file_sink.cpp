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

    mxfile -> write(json_string, calculator_filename_);

    mxfile-> flush();
    
}

void file_sink::set_pattern(const std::string &pattern){
    formatter_ =  std::unique_ptr<mxlogger::pattern_formatter>(new mxlogger::pattern_formatter(pattern));
}

void file_sink::set_policy(policy::storage_policy policy){
   
    handle_date_(policy);
    
}
void file_sink::set_filename(const std::string filename){
    filename_ = filename;
}

void file_sink::handle_date_(policy::storage_policy policy){


    std::tm tm_time = mxlogger_helper::now();


    switch (policy) {
        case policy::storage_policy::yyyy_MM:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1);
            
        }
            break;
        case policy::storage_policy::yyyy_ww:
        {
            int wd = 0 , yd = 0;
            time_t t;
            struct tm *ptr;
            time(&t);
            ptr = gmtime(&t);
            wd = ptr->tm_wday;
            yd = ptr->tm_yday;
            int base = 7 - (yd + 1 - (wd + 1)) % 7;
            if (base == 7){
                base = 0;
            }
           int  week_n = (base + yd) / 7 + 1;

            auto result = mxlogger_helper::string_format("%04d-%s%s",  tm_time.tm_year + 1900,week_n);

            calculator_filename_ = result;
        }
            break;
        case policy::storage_policy::yyyy_MM_dd:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday);
            calculator_filename_ = result;
        }

            break;
        case policy::storage_policy::yyyy_MM_dd_HH:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, tm_time.tm_hour);

            calculator_filename_ = result;
        }
            break;

        default:
            calculator_filename_ = "null";
            break;
    }
    
    calculator_filename_ = filename_ + "_" + calculator_filename_ + ".log";
}


void file_sink::flush() {
    mxfile -> flush();
}
};

};
