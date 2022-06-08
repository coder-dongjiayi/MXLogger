//
//  sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef sink_hpp
#define sink_hpp

#include <stdio.h>
#include "log_enum.h"
#include "log_serialize.h"
namespace mxlogger{
namespace sinks {

class sink{
protected:
    std::atomic_int level_{level::debug};
    
    void handle_date(policy::storage_policy policy);
    
    std::string filename_;
    
public:
    virtual ~sink() = default;
           
    virtual void log(const void* buffer, size_t buffer_size,  level::level_enum level) = 0;
    
    
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
