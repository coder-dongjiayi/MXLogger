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
namespace mxlogger{

memory_mmap::memory_mmap(const std::string &dir_path):dir_path_(dir_path),page_size_(static_cast<size_t>(getpagesize())){

    if (mxlogger::create_dir(dir_path) == false) {
        printf("[mxlogger_error]memory_mmap error:%s\n",strerror(errno));
    }
    
}
memory_mmap::~memory_mmap(){
    
    close(fd_);
}

bool memory_mmap::ope_file_(){
    
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
    
    // 扩容文件
    truncate_(file_size_);
    
    return true;
    
}

bool memory_mmap::truncate_(size_t size){
   
    
    if (size <= 0 || size % page_size_ != 0) {
        size_t capacity_size =  (( size / page_size_) + 1) * page_size_;
        
        if (ftruncate(fd_, static_cast<off_t>(capacity_size)) != 0) {
            printf("[mxlogger_error]truncate_ error:%s\n",strerror(errno));
        
            return  false;
        }
    }
    
    if(mmap_ptr_ != nullptr){
        if (munmap(mmap_ptr_, file_size_) != 0) {
            printf("[mxlogger_error]munmap_ error:%s\n",strerror(errno));
            return false;
        }
    }
    
    file_size_ = mxlogger::file_size(mmap_disk_path_.c_str());

    
    return mmap();
   
}
bool memory_mmap::mmap(){
    
    void* result =  ::mmap(NULL, file_size_, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_SHARED, fd_, 0);
    
    if (result == MAP_FAILED) {
        mmap_ptr_ = nullptr;
        printf("[mxlogger_error]start_mmap error:%s\n",strerror(errno));
        fd_ = -1;
        close(fd_);
        return  false;
    }
    mmap_ptr_ = (char*)result;
    
    
    return  true;
}


bool memory_mmap::write_data(const std::string &buf,const std::string &fname){
  
    mmap_disk_path_ = dir_path_ + fname;
    
    if (fd_  < 0 || filename_.compare(fname) != 0 || path_exists((mmap_disk_path_).data()) == false) {
        filename_ = fname;
        if(ope_file_() == false) return false;
     
    }
    
    
    char * data = (char*)buf.data();
      
    size_t length = buf.size();
      
    
    void* result =  memcpy(mmap_ptr_, data, length);
    
    if (result == nullptr) {
        printf("[mxlogger_error] write_data error:%s\n",strerror(errno));
        return  false;
    }
    mmap_ptr_ = mmap_ptr_ + length;
    
    
    return true;
}


}
