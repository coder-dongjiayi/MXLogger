//
//  mxlogger_helper.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef mxlogger_helper_hpp
#define mxlogger_helper_hpp

#include <stdio.h>

#include <memory>
#include <string>
#include <stdexcept>
namespace mxlogger_helper{
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

std::tm localtime(const std::time_t &time_tt)
{
    std::tm tm;
    ::localtime_r(&time_tt, &tm);
    return tm;
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
