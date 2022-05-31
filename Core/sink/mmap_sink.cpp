//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#include "mxlogger_helper.hpp"
#include "../cJson/cJSON.h"
#include "mxlogger_file_util.hpp"
namespace mxlogger{
namespace sinks{

mmap_sink::mmap_sink(const std::string &dir_path,policy::storage_policy policy){
    
    handle_date_(policy);
    mmap_ =  std::make_shared<memory_mmap>(dir_path);
    
}
void mmap_sink::log(const details::log_msg &msg){
   
    if (should_log(msg.level) == false) {
        return;
    }
  
    mmap_->write_data(msg.json_string.data(),filename_);
    
    
}
void mmap_sink::flush() {
   
}


void mmap_sink::handle_date_(policy::storage_policy policy){


    std::tm tm_time = mxlogger_helper::now();


    switch (policy) {
        case policy::storage_policy::yyyy_MM:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1);
            filename_ = result;
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

            filename_ = result;
        }
            break;
        case policy::storage_policy::yyyy_MM_dd:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday);
            filename_ = result;
        }

            break;
        case policy::storage_policy::yyyy_MM_dd_HH:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d-%02d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, tm_time.tm_hour);

            filename_ = result;
        }
            break;

        default:
            filename_ = "null";
            break;
    }
    filename_ = filename_ + ".log";
    
}


};


};
