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

#include "log_msg.hpp"
#include "../aes/aes_crypt.hpp"
#include "../debug_log.hpp"
namespace mxlogger{
namespace sinks {

class sink{
private:
  
   
    aes_crypt crypt_;
    
    const char* crypt_iv_ = nullptr;

    bool is_aes = false;
    
    
protected:
    std::atomic_int level_{level::debug};
    
  
    
    void cfb128_encrypt(const void *input, void *output, size_t length);
    
public:
    virtual ~sink() = default;
           
    
    virtual void log(const details::log_msg& msg) = 0;
    
    // 刷新
    virtual void flush() = 0;
    // 设置日志等级
    void set_level(level::level_enum log_level);
    
    // 判断是否应该打印日志
    bool should_log(level::level_enum mesg_level);
    
    // 是否可以加密
    bool should_encrypt();
    
    // 获取日志等级
    level::level_enum level() const;
    
    // 初始化AES
    void init_aescfb(const char* crypt_key,const char* crypt_iv);
    

  
};
};

};
#endif /* sink_hpp */
