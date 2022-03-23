//
//  async_logger.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#ifndef async_logger_hpp
#define async_logger_hpp

#include <stdio.h>
#include "logger.hpp"

namespace mxlogger{

class thread_pool;

class async_logger final : public std::enable_shared_from_this<async_logger>,public logger{
    
    friend class thread_pool;
    
public:


    async_logger(std::string logger_name, sink_ptr single_sink, std::weak_ptr<thread_pool> tp) : logger(std::move(logger_name),single_sink),thread_pool_(std::move(tp)){
        
    
        
    }
protected:
    void sink_it_(const details::log_msg &log_msg) override;
    void flush() override;
    
    void backend_sink_it_(const details::log_msg &log_msg);
    void backend_flush();
private:
    
    std::weak_ptr<thread_pool> thread_pool_;
};


}


#endif /* async_logger_hpp */
