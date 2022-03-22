//
//  yjdlog.hpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#pragma once

#include <stdio.h>

#include "log_msg.h"

#include <mutex>
namespace blinglog {
namespace mutex{

struct console_mutex{
    using mutex_t = std::mutex;
    static mutex_t &mutex(){
        static mutex_t s_mutex;
        return s_mutex;
    }
};
}

}


namespace blinglog {
namespace sinks{
class sink{
    
protected:
    //默认日志输出等级 debug
    level_t level_{level::debug};
public:
    using mutex_t = typename mutex::console_mutex;
    
    virtual ~sink() = default;
           
    virtual void log(const details::log_msg &msg) = 0;
    
    virtual void set_pattern(const std::string &pattern) = 0;
    
    // 刷新
    virtual void flush() = 0;
    // 设置日志等级
    void set_level(level::level_enum log_level);
    
    // 判断是否应该打印日志
     bool should_log(level::level_enum mesg_level);
    
    // 获取日志等级
    level::level_enum level() const;
   
};
}
}


