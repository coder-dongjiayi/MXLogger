//
//  formatter.cpp
//  Logger
//
//  Created by 董家祎 on 2022/2/26.
//

#include "formatter.hpp"


inline void append_string_view(string_view_t view,memory_buf_t &dest){
    auto * buf_prt = view.data();
    dest.append(buf_prt, buf_prt + view.size());

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

namespace blinglog{

formatter::formatter(): eol_(default_eol){}




std::tm  formatter::localtime_(const std::time_t &time_tt){
    
    std::tm tm;
    ::localtime_r(&time_tt,&tm);
    return tm;
}


}
