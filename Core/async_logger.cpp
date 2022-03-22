//
//  async_logger.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#include "async_logger.hpp"
#include "thread_pool.hpp"
#include "sinks.h"
namespace blinglog{



void async_logger:: sink_it_(const details::log_msg &log_msg){
    std::shared_ptr<thread_pool> pool_ptr = thread_pool_.lock();
    
    
    if (pool_ptr) {
        pool_ptr -> post_log(shared_from_this(),log_msg);
    }else{
        printf("sink_it_ 当前线程没有数据");
    }
}
void async_logger::flush(){
    if (std::shared_ptr<thread_pool> pool_ptr = thread_pool_.lock()) {
        
        pool_ptr -> post_flush(shared_from_this());
    }else{
        printf("flush 当前线程没有数据");
    }
}

void async_logger::backend_sink_it_(const details::log_msg &log_msg){
   
    if (current_sink->should_log(log_msg.level)) {
        current_sink->log(log_msg);
    }
   
    
}
void async_logger::backend_flush(){
    current_sink->flush();
}
}
