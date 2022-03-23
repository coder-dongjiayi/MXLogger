//
//  mpmc_blocking_queue.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/7.
//

#ifndef mpmc_blocking_queue_hpp
#define mpmc_blocking_queue_hpp
#include <stdio.h>
#include <vector>
#include <condition_variable>
#include <mutex>
namespace mxlogger{
namespace details{

template<typename T>

class mpmc_blocking_queue{
public:
    using  item_type = T;
    explicit mpmc_blocking_queue(size_t max_items): max_items_(max_items){}
     
    void enqueue(T &&item){
        {
            std::unique_lock<std::mutex> lock(queue_mutex_);
            pop_cv_.wait(lock, [this]{
                return  queue_.size() != max_items_;
            });
            queue_.push_back(std::move(item));
            
        }
        
        push_cv_.notify_one();
        
    }
    
    bool dequeue_for(T &popped_item,std::chrono::milliseconds wait_duration){
        {
            std::unique_lock<std::mutex> lock(queue_mutex_);
           bool r =  push_cv_.wait_for(lock, wait_duration,[this]{
                return !queue_.empty();
            });
            if(r == false){
                return  false;
            }
            popped_item =  std::move(queue_.front());
            queue_.erase(queue_.begin());
        }
        
        pop_cv_.notify_one();
        return  true;
    }
private:
    
    std::mutex queue_mutex_;
    std::condition_variable push_cv_;
    std::condition_variable pop_cv_;
    
    std::vector<T> queue_;
    
    /// 队列最大数量
    size_t max_items_;
};

}


}


#endif /* mpmc_blocking_queue_hpp */
