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
extern "C"
   {
#include "md5/md5.h"
   }

namespace mxlogger_helper{


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
};


#endif /* mxlogger_helper_hpp */
