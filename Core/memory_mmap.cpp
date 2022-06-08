//
//  memory_mmap.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "memory_mmap.hpp"
#include <sys/mman.h>
#include <sys/file.h>
#include <unistd.h>
#include "mxlogger_file_util.hpp"

static const size_t offset_actual = sizeof(uint32_t);

namespace mxlogger{

memory_mmap::memory_mmap(const std::string &dir_path,const std::string &fname):dir_path_(dir_path),page_size_(static_cast<size_t>(getpagesize())){

    if (mxlogger::create_dir(dir_path) == false) {
        printf("[mxlogger_error]memory_mmap error:%s\n",strerror(errno));
    }

}
memory_mmap::~memory_mmap(){
    
    close(fd_);
    munmap(mmap_ptr_, file_size_);
  
}

bool memory_mmap::ope_file_(){
    
    // 打开新的文件的时候 内存中的actual_size_ 应该被清零
    actual_size_ = 0;
    
    if (fd_ > 0) {
        close(fd_);
    }
        
    fd_ =  open(mmap_disk_path_.c_str(), O_RDWR|O_CLOEXEC|O_CREAT,S_IRWXU);
    if (fd_ < 0) {
        printf("[mxlogger_error]ope_file_ error:%s\n",strerror(errno));
        file_size_ = 0;
        return  false;
    }
    
    file_size_ = mxlogger::file_size(mmap_disk_path_.c_str());
    
    // 扩容文件 并且建立内存映射
    truncate_(file_size_);
    
    return true;
    
}


void memory_mmap::write_actual_size(size_t size){
    
    memcpy(mmap_ptr_, &size, offset_actual);
    
    actual_size_ = size;
}

// 获取文件真实大小

size_t memory_mmap::get_actual_size(){
    
    uint32_t actual_size;
    
    memcpy(&actual_size, mmap_ptr_, offset_actual);
    
    return actual_size;
}

bool memory_mmap::truncate_(size_t size){
   
    if(size <= 0 || size % page_size_ != 0){
        size_t capacity_size =  (( size / page_size_) + 1) * page_size_;

        if (ftruncate(fd_, static_cast<off_t>(capacity_size)) != 0) {
            printf("[mxlogger_error]truncate_ error:%s\n",strerror(errno));
        
            return  false;
        }
        
        if(mmap_ptr_ != nullptr){
            if (munmap(mmap_ptr_, file_size_) != 0) {
                printf("[mxlogger_error]munmap_ error:%s\n",strerror(errno));
                return false;
            }
            mmap_ptr_ = nullptr;
        }
        file_size_ = capacity_size;
    }
 
    
    return mmap_ptr_ == nullptr ? mmap() : true;
   
}

// 建立文件与内存的映射
bool memory_mmap::mmap(){
    
    mmap_ptr_ =  (uint8_t*)::mmap(NULL, file_size_, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_SHARED, fd_, 0);
    
    if (mmap_ptr_ == MAP_FAILED) {
        mmap_ptr_ = nullptr;
        printf("[mxlogger_error]start_mmap error:%s\n",strerror(errno));
        fd_ = -1;
        close(fd_);
        return  false;
    }
    
    return  true;
}



bool memory_mmap::write_data(const void* buffer, size_t buffer_size, const std::string &fname){
  
    mmap_disk_path_ = dir_path_ + fname;
    
    if (fd_  < 0 || filename_.compare(fname) != 0 || path_exists((mmap_disk_path_).data()) == false) {
        filename_ = fname;
        if(ope_file_() == false) return false;
        actual_size_ = get_actual_size();
    }
    
    size_t total = actual_size_ + buffer_size ;
    
    if (total >= file_size_) {
        truncate_(total + 1);
    }
    
    memcpy(mmap_ptr_  + offset_actual + actual_size_, buffer, buffer_size);
    
    write_actual_size(total);
    
    return true;
}


bool memory_mmap::msync_(int flag){
    if (msync(mmap_ptr_, file_size_, flag) != 0) {
        printf("[mxlogger_error]msync_ error:%s\n",strerror(errno));
        return false;
    }
    return true;
   
}

bool memory_mmap::sync(){
    
    return msync_(MS_SYNC);
}

bool memory_mmap::async(){
    return msync_(MS_ASYNC);
}

}
