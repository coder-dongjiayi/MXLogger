//
//  fmt_helper.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#ifndef fmt_helper_h
#define fmt_helper_h

#include "logger_common.h"
namespace mxlogger{
namespace  details{
namespace  fmt_helper{


template<typename T>
inline void append_int(T n,memory_buf_t &dest){
    fmt_lib::format_int i(n);
    dest.append(i.data(), i.data() + i.size());
}

inline void append_string_view(string_view_t view,memory_buf_t &dest){
    auto * buf_prt = view.data();
    dest.append(buf_prt, buf_prt + view.size());

}
inline void pad2(int n, memory_buf_t &dest)
{
    if (n >= 0 && n < 100) // 0-99
    {
        dest.push_back(static_cast<char>('0' + n / 10));
        dest.push_back(static_cast<char>('0' + n % 10));
    }
    else // unlikely, but just in case, let fmt deal with it
    {
        fmt_lib::format_to(std::back_inserter(dest), "{:02}", n);
    }
}

template<typename T>
inline void pad3(T n, memory_buf_t &dest)
{
    static_assert(std::is_unsigned<T>::value, "pad3 must get unsigned T");
    if (n < 1000)
    {
        dest.push_back(static_cast<char>(n / 100 + '0'));
        n = n % 100;
        dest.push_back(static_cast<char>((n / 10) + '0'));
        dest.push_back(static_cast<char>((n % 10) + '0'));
    }
    else
    {
        append_int(n, dest);
    }
}
template<typename ToDuration>
inline ToDuration time_fraction(log_clock::time_point tp)
{
    using std::chrono::duration_cast;
    using std::chrono::seconds;
    auto duration = tp.time_since_epoch();
    auto secs = duration_cast<seconds>(duration);
    return duration_cast<ToDuration>(duration) - duration_cast<ToDuration>(secs);
}

}
}
}
#endif /* fmt_helper_h */
