//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#include <sys/mman.h>
#include "log_serialize.h"
static const size_t offset_length = sizeof(uint32_t);

namespace mxlogger{
namespace sinks{
mmap_sink::~mmap_sink(){
    munmap_();
}

void mmap_sink::log(const void* buffer, size_t buffer_size,  level::level_enum level){
   
    if (should_log(level) == false) {
        return;
    }
    
    write_data_(buffer, buffer_size, filename_);

    
}
bool mmap_sink::write_data_(const void* buffer, size_t buffer_size, const std::string &fname){
    
    if (file_ident < 0 || filename_.compare(fname) !=0) {
        open(fname);
        truncate_(get_file_size());
        actual_size_ = get_actual_size_();
    }
    
    ///1.、需要写入字节总大小 = 当前文件真实长度 + 需要写入buffer的长度 + offset_length
    
    size_t total = actual_size_ + buffer_size + offset_length;
    
    /// 2、 如果写入长度大于文件长度 进行扩容
    if (total >= get_file_size()) {
        
        truncate_(total + 1);
    }
    
    uint8_t* write_ptr = mmap_ptr_  + offset_length + actual_size_;
    
    ///3.、先写入buffer 长度
    memcpy(write_ptr, &buffer_size, offset_length);
    
    ///4、 再写buffer数据
    memcpy(write_ptr + offset_length, buffer, buffer_size);
    
    ///5、更新文件真实大小
    write_actual_size_(total);

    return true;
}

void mmap_sink::write_actual_size_(size_t size){
    
    memcpy(mmap_ptr_, &size, offset_length);
    
    actual_size_ = size;
}

size_t mmap_sink::get_actual_size_(){
    uint32_t actual_size;
    
    memcpy(&actual_size, mmap_ptr_, offset_length);
    
    return actual_size;
}
bool mmap_sink::truncate_(size_t size){
   
    if(size <= 0 || size % page_size_ != 0){
        size_t capacity_size =  (( size / page_size_) + 1) * page_size_;

        if(ftruncate(capacity_size) == false){
            return false;
        }
        
        munmap_();
    
    }
 
    
    return mmap_ptr_ == nullptr ? mmap_() : true;
   
}
// 解除映射
bool mmap_sink::munmap_(){
    if(mmap_ptr_ != nullptr){
        if (munmap(mmap_ptr_, get_file_size()) != 0) {
            printf("[mxlogger_error]munmap_ error:%s\n",strerror(errno));
            return false;
        }
        mmap_ptr_ = nullptr;
    }
    return true;
}

// 建立文件与内存的映射
bool mmap_sink::mmap_(){
    
    mmap_ptr_ =  (uint8_t*)::mmap(NULL, get_file_size(), PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_SHARED, file_ident, 0);
    
    if (mmap_ptr_ == MAP_FAILED) {
        mmap_ptr_ = nullptr;
        printf("[mxlogger_error]start_mmap error:%s\n",strerror(errno));
        close();
        
        return  false;
    }
    
    return  true;
}

void mmap_sink::flush() {
    sync_();
}
bool mmap_sink::msync_(int flag){
    if (msync(mmap_ptr_, get_file_size(), flag) != 0) {
        printf("[mxlogger_error]msync_ error:%s\n",strerror(errno));
        return false;
    }
    return true;
   
}

bool mmap_sink::sync_(){
    
    return msync_(MS_SYNC);
}

bool mmap_sink::async_(){
    return msync_(MS_ASYNC);
}


};


};
