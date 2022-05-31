//
//  sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef sink_hpp
#define sink_hpp

#include <stdio.h>
#include "log_msg.hpp"
#include "pattern_formatter.hpp"
namespace mxlogger{
namespace sinks {

class sink{
protected:
    std::atomic_int level_{level::debug};
    
    std::string pattern_;
    
    std::unique_ptr<pattern_formatter> formatter_;
    
    void handle_date(policy::storage_policy policy);
    
    std::string filename_;
    
public:
    virtual ~sink() = default;
           
    virtual void log(const details::log_msg &msg) = 0;
    
    
    // 刷新
    virtual void flush() = 0;
    // 设置日志等级
    void set_level(level::level_enum log_level);
    
    // 判断是否应该打印日志
     bool should_log(level::level_enum mesg_level);
    
    
    // 获取日志等级
    level::level_enum level() const;
};
};

};
#endif /* sink_hpp */
