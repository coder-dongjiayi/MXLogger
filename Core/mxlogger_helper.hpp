//
//  mxlogger_helper.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef mxlogger_helper_hpp
#define mxlogger_helper_hpp

#include <stdio.h>
#include <chrono>
#include <memory>
#include <string>
#include <stdexcept>
#include "log_enum.h"
extern "C"
   {
#include "md5/md5.h"
   }

namespace mxlogger_helper{



inline level::level_enum level_(int lvl){
  
    switch (lvl) {
        case 0:
            return level::level_enum::debug;
        case 1:
            return level::level_enum::info;
        case 2:
            return level::level_enum::warn;
        case 3:
            return level::level_enum::error;
        case 4:
            return level::level_enum::fatal;
            
        default:
            return level::level_enum::debug;
    }
    
}
inline policy::storage_policy policy_(const char* storage_policy){
    
    if (storage_policy == nullptr) {
        return policy::storage_policy::yyyy_MM_dd;
    }
    if (strcmp(storage_policy, "yyyy_MM") == 0) {
        return policy::storage_policy::yyyy_MM;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd") == 0) {
        return policy::storage_policy::yyyy_MM_dd;
    }
    if (strcmp(storage_policy, "yyyy_ww") == 0) {
        return policy::storage_policy::yyyy_ww;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd_HH") == 0) {
        return policy::storage_policy::yyyy_MM_dd_HH;;
    }
    return policy::storage_policy::yyyy_MM_dd;
}




template <typename T>
inline std::string mx_md5(const std::basic_string<T> &value) {
 
    uint8_t md[16] = {};
    char tmp[3] = {}, buf[33] = {};
    MD5((const uint8_t *) value.c_str(), value.size() * (sizeof(T) / sizeof(uint8_t)), md);
    for (auto ch : md) {
        snprintf(tmp, sizeof(tmp), "%2.2x", ch);
        strcat(buf, tmp);
    }
    return {buf};
}


template<typename ... Args>
std::string string_format( const std::string& format, Args ... args )
{
    int size_s = std::snprintf( nullptr, 0, format.c_str(), args ... ) + 1; // Extra space for '\0'
    if( size_s <= 0 ){ throw std::runtime_error( "Error during formatting." ); }
    auto size = static_cast<size_t>( size_s );
    std::unique_ptr<char[]> buf( new char[ size ] );
    std::snprintf( buf.get(), size, format.c_str(), args ... );
    return std::string( buf.get(), buf.get() + size - 1 ); // We don't want the '\0' inside
}

inline std::tm localtime(const std::time_t &time_tt)
{
    std::tm tm;
    ::localtime_r(&time_tt, &tm);
    return tm;
}
inline std::tm now(){

    const std::time_t tt = std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());

    return localtime(tt);
}



template<typename ToDuration>
inline ToDuration time_fraction(std::chrono::system_clock::time_point tp)
{
    using std::chrono::duration_cast;
    using std::chrono::seconds;
    auto duration = tp.time_since_epoch();
    auto secs = duration_cast<seconds>(duration);
    return duration_cast<ToDuration>(duration) - duration_cast<ToDuration>(secs);
}


inline int64_t time_stamp_microseconds(std::chrono::system_clock::time_point time)
{
    
    std::chrono::time_point<std::chrono::system_clock, std::chrono::microseconds> tp = std::chrono::time_point_cast<std::chrono::microseconds>(time);
    auto tmp = std::chrono::duration_cast<std::chrono::microseconds>(tp.time_since_epoch());
    return tmp.count();
    
   
}

inline std::string micros_time(std::chrono::system_clock::time_point time){
    std::tm tm_time = mxlogger_helper::localtime(std::chrono::system_clock::to_time_t(time));
        
    auto micro = mxlogger_helper::time_fraction<std::chrono::microseconds>(time);

    using std::chrono:: milliseconds;
    std::string time_str =  mxlogger_helper::string_format("%02d:%02d:%02d.%06d", tm_time.tm_hour,tm_time.tm_min,tm_time.tm_sec,micro);
    return time_str;
}

inline std::string micros_datetime(std::chrono::system_clock::time_point time){
    std::tm tm_time = mxlogger_helper::localtime(std::chrono::system_clock::to_time_t(time));
        
    auto micro = mxlogger_helper::time_fraction<std::chrono::microseconds>(time);

    using std::chrono:: milliseconds;
    std::string time_str =  mxlogger_helper::string_format("%04d-%02d-%02d %02d:%02d:%02d.%06d", tm_time.tm_year + 1900, tm_time.tm_mon + 1, tm_time.tm_mday, tm_time.tm_hour,tm_time.tm_min,tm_time.tm_sec,micro);
    return time_str;
}

};


#endif /* mxlogger_helper_hpp */
