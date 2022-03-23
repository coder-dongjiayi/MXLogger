//
//  async_msg.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#ifndef async_msg_hpp
#define async_msg_hpp
#include "async_logger.hpp"
#include <stdio.h>
#include "log_msg_buffer.hpp"
namespace mxlogger {

namespace details{
using async_logger_ptr = std::shared_ptr<async_logger>;
enum class async_msg_type
{
    log,
    flush,
    terminate
};

struct async_msg : log_msg_buffer {
    async_msg_type msg_type;
    async_logger_ptr worker_ptr;
  
    
    async_msg() = default;
    ~async_msg() = default;
    
    async_msg(async_logger_ptr &&worker,async_msg_type type,const details::log_msg &log_msg):msg_type{type},worker_ptr{std::move(worker)},log_msg_buffer{log_msg}{};
    
    async_msg(async_logger_ptr &&worker,async_msg_type type): async_msg{std::move(worker),type,log_msg_buffer{}} {};
    
    async_msg(async_msg_type type): async_msg{nullptr,type,log_msg_buffer{}} {};
    
};


}
}



#endif /* async_msg_hpp */
