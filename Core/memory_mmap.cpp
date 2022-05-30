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
    
    std::string file_path = dir_path_ + filename_;
        
    fd_ =  open(file_path.c_str(), O_RDWR|O_CLOEXEC|O_CREAT,S_IRWXU);
    if (fd_ < 0) {
        printf("[mxlogger_error]ope_file_ error:%s\n",strerror(errno));
        file_size_ = 0;
        return  false;
    }
    
    file_size_ = mxlogger::file_size(file_path.c_str());
    
    return true;
    
       
}
bool memory_mmap::start_mmap(size_t size){
    
    void* result =  mmap(NULL, size, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_SHARED, fd_, 0);
    
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
bool memory_mmap::truncate_(size_t size){
    size_t capacity_size = file_size_;
    
    if (size <= 0 || size % page_size_ != 0) {
         capacity_size =  (( size / page_size_) + 1) * page_size_;
        
        if (ftruncate(fd_, static_cast<off_t>(capacity_size)) != 0) {
            printf("[mxlogger_error]truncate_ error:%s\n",strerror(errno));
        
            return  false;
        }
       
    }
   
    
    return true;
}

bool memory_mmap::write_data(const std::string &buf,const std::string &fname){
  
    
    if (fd_  < 0 || filename_.compare(fname) != 0 || path_exists((dir_path_ + filename_).data()) == false) {
        filename_ = fname;
        if(ope_file_() == false) return false;
        
        if (truncate_(0) == false) return false;
        
        if (start_mmap(page_size_) == false) return false;
    }
    
    char * data = (char*)buf.data();
      
    size_t length = buf.size();
      
    size_t total_length = strlen(mmap_ptr_);
    
    if (total_length <= file_size_) {
        truncate_(total_length);
    }
    
    void* result =  memcpy(mmap_ptr_, data, length);
    
    if (result == nullptr) {
        printf("[mxlogger_error] write_data error:%s\n",strerror(errno));
        return  false;
    }
    mmap_ptr_ = mmap_ptr_ + length;
    
    
    return true;
}


}
