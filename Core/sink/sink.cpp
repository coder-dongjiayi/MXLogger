//
//  sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "sink.hpp"
#include "mxlogger_helper.hpp"
namespace mxlogger{
namespace sinks{
void sink::set_level(level::level_enum log_level){
     level_.store(log_level,std::memory_order_relaxed);
}

bool sink::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}


level::level_enum  sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}
void sink::handle_date(policy::storage_policy policy){


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
}
