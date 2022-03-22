//
//  file_appender.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/9.
//

#include "file_appender.hpp"


namespace blinglog{
namespace details{

file_appender::file_appender():policy_(policy::storage_policy::yyyy_MM_dd),filename_("blinglog"){
    handle_date_(policy_);
}


file_appender::~file_appender(){
    
}
void file_appender::set_policy(policy::storage_policy policy){
    handle_date_(policy);
}
void file_appender::set_filename(const std::string filename){
    
    filename_ = filename;
}
std::string file_appender::calc_filename(){
    return calculator_filename_;
}

void file_appender::handle_date_(policy::storage_policy policy){
 
    std::tm tm_time =   fmt_lib::localtime(log_clock::now());
   
    
    switch (policy) {
        case policy::storage_policy::yyyy_MM:
        {
            auto result = fmt_lib::format("{}_{:04d}-{:02d}{}", filename_, tm_time.tm_year + 1900, tm_time.tm_mon + 1,".log");
            calculator_filename_ = result;
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
            
            auto result = fmt_lib::format("{}_{:04d}-{}{}", filename_, tm_time.tm_year + 1900,week_n,".log");
            
            calculator_filename_ = result;
        }
            break;
        case policy::storage_policy::yyyy_MM_dd:
        {
            auto result = fmt_lib::format("{}_{:04d}-{:02d}-{:02d}{}", filename_, tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, ".log");
            calculator_filename_ = result;
        }
            
            break;
        case policy::storage_policy::yyyy_MM_dd_HH:
        {
            auto result = fmt_lib::format("{}_{:04d}-{:02d}-{:02d}-{:02d}{}", filename_, tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, tm_time.tm_hour, ".log");
            calculator_filename_ = result;
        }
            break;
        
        default:
            break;
    }
}


}


}
