//
//  thread_pool.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#include "thread_pool.hpp"
namespace mxlogger{

thread_pool::thread_pool(size_t queue_max_items,size_t threads_number) : queue_(queue_max_items){
    if(threads_number < 0 || threads_number > 1000){
        return;
    }
    
    for (size_t i = 0; i< threads_number; i++) {
        threads_.emplace_back([this]{
            while (process_next_msg_()) {}
        });
    }
   
}

thread_pool::~thread_pool(){
    
    for (size_t i =0 ; i < threads_.size(); i++) {
        post_async_msg_(details::async_msg(details::async_msg_type::terminate));
    }
    
    for (auto &t : threads_) {
        t.join();
    }
}

void thread_pool::post_log(details::async_logger_ptr &&worker_ptr, const details::log_msg &log_msg){
    details::async_msg async_m(std::move(worker_ptr),details::async_msg_type::log,log_msg);
    post_async_msg_(std::move(async_m));
    
}
void thread_pool::post_flush(details::async_logger_ptr &&worker_ptr){
    details::async_msg async_m(std::move(worker_ptr),details::async_msg_type::flush);
    post_async_msg_(std::move(async_m));
}

void thread_pool::post_async_msg_(details::async_msg &&msg){
    
    queue_.enqueue(std::move(msg));
}

bool thread_pool::process_next_msg_(){
    
    details::async_msg incoming_async_msg;
    bool dequeued = queue_.dequeue_for(incoming_async_msg, std::chrono::seconds(10));
    if (dequeued == false) {
        return  true;
    }
    switch (incoming_async_msg.msg_type) {
        case details::async_msg_type::log:
            incoming_async_msg.worker_ptr->backend_sink_it_(incoming_async_msg);
            break;
        case details::async_msg_type::flush:
            incoming_async_msg.worker_ptr->backend_flush();
            break;
        case details::async_msg_type::terminate:{
            return  false;
        }
            
            
        default:
            {
                return  false;
            };
    }
    return true;
}



}
