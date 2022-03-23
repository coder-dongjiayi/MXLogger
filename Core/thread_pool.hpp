//
//  thread_pool.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#ifndef thread_pool_hpp
#define thread_pool_hpp
#include "async_msg.hpp"
#include "mpmc_blocking_queue.hpp"
#include <memory>
#include <thread>
#include <vector>
#include <functional>

namespace mxlogger{



class thread_pool{
  
public:
    using item_type = details::async_msg;
    
    /// queue_max_items 队列最大数量
    /// threads_number 线程并发数量
    thread_pool(size_t queue_max_items,size_t threads_number);
    
    ~thread_pool();
    
    void post_log(details::async_logger_ptr &&worker_ptr,const details::log_msg &log_msg);
    
    void post_flush(details::async_logger_ptr &&worker_ptr);
    
private:
    std::vector<std::thread> threads_;
    bool process_next_msg_();
    void post_async_msg_(details::async_msg &&msg);
    details::mpmc_blocking_queue<item_type> queue_;
    
};


}



#endif /* thread_pool_hpp */
