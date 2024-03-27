//
//  mmap_sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#ifndef mmap_sink_hpp
#define mmap_sink_hpp

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "base_file_sink.hpp"

namespace mxlogger{
namespace sinks {
class mmap_sink : public base_file_sink{
public:
    
    mmap_sink(const std::string &dir_path,const std::string &filename, policy::storage_policy policy);
    
    ~mmap_sink();
    int log(const details::log_msg& msg) override;
    
    
    void add_file_heder(const char* msg);
    
    
    void flush() override;

private:
    
 
    size_t file_size_ = 0;
    
    //一页内存大小
    size_t page_size_ = 0;
    
    //文件真实大小
    size_t actual_size_ = 0;
  
    // 映射内存首地址
    uint8_t* mmap_ptr_ = nullptr;
    
    int write_data_(const void* buffer, size_t buffer_size);
    
    int truncate_(size_t size);
    
    bool mmap_();
    bool munmap_();
    
    size_t get_actual_size_();
    
    void write_actual_size_(size_t size);
    int log_(const details::log_msg& msg);
   
    bool msync_(int flag);
     bool sync_();
     
     bool async_();
     
    
};



}
}
#endif /* mmap_sink_hpp */
