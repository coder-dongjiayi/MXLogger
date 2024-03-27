//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#include <sys/mman.h>
#include <cerrno>
#include "../log_serialize.h"


static const size_t offset_length = sizeof(uint32_t);


namespace mxlogger{
namespace sinks{
mmap_sink::mmap_sink(const std::string &dir_path, const std::string &filename,policy::storage_policy policy):base_file_sink(dir_path,filename,policy),page_size_(static_cast<size_t>(getpagesize())){

    
    open();
    file_size_ = get_file_size();
    if (file_size_ == 0) {
        truncate_(0);
        
    }else{
        mmap_();
    }

    actual_size_ = get_actual_size_();
    
    
}
mmap_sink::~mmap_sink(){
    munmap_();
    MXLoggerInfo("mmap_sink delloc");
}
int mmap_sink::log(const details::log_msg& msg){
    if (should_log(msg.level) == false) {
        return 0;
    }
    
    return  log_(msg);
}

void mmap_sink::add_file_heder(const char* msg){
    
    if(actual_size_ !=0 || msg == nullptr) return;
    details::log_msg log_msg(level::level_enum::debug,"com.djy.mxlogger.fileHeader",nullptr,msg,true);
    log_(log_msg);
}


int mmap_sink::log_(const details::log_msg& msg){
    flatbuffers::FlatBufferBuilder builder;
    
    auto root =  Createlog_serializeDirect(builder,msg.name,msg.tag,msg.msg,msg.level,(uint32_t)msg.thread_id,msg.is_main_thread,msg.time_stamp);
   
    builder.Finish(root);
     auto buffer =  builder.Release();
    
    uint8_t* point = buffer.data();
    uint32_t size = (uint32_t)buffer.size();
    
    
    if (should_encrypt()) {
        cfb128_encrypt(point, point, size);
    }
    
    return  write_data_(point, size);
 
}

int mmap_sink::write_data_(const void* buffer, size_t buffer_size){
    
    
    ///1.、需要写入字节总大小 = 当前文件真实长度 + 需要写入buffer的长度 + offset_length
    
    size_t total = actual_size_ + buffer_size + offset_length;
    
    /// 2、 如果写入长度大于文件长度进行扩容
    if (total >=file_size_) {
        /// 扩容逻辑失败 就不往下进行了
       int r =  truncate_(total);
        if(r != 0){
            return r;
        }
    }
    
    uint8_t* write_ptr = mmap_ptr_  + offset_length + actual_size_;
    
    
    ///3.、先写入buffer 长度
    memcpy(write_ptr, &buffer_size, offset_length);
    
  
    ///4、 再写buffer数据
    memcpy(write_ptr + offset_length, buffer, buffer_size);
    
    
    ///5、更新文件真实大小
    write_actual_size_(total);

    return 0;
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
//扩容
/// 0 成功  -1 扩容失败 -2 解除映射失败 -3 映射失败
int mmap_sink::truncate_(size_t size){
   
    size_t capacity_size =  (( size / page_size_) + 1) * page_size_;

    if(ftruncate(capacity_size) == false){
        return -1;
    }
    if(munmap_() == false){
        return -2;
    }
    
    file_size_ = capacity_size;
    
    if(mmap_ptr_ != nullptr){
        return 0;
    }
    if(mmap_() == false){
        return -3;
    }
    return 0;
   
}
// 解除映射
bool mmap_sink::munmap_(){
    if(mmap_ptr_ != nullptr){
        if (munmap(mmap_ptr_, file_size_) != 0) {
        
            MXLoggerError("munmap_ error:%s",strerror(errno));
                          
            return false;
        }
        mmap_ptr_ = nullptr;
    }
    return true;
}

// 建立文件与内存的映射
bool mmap_sink::mmap_(){
    
    mmap_ptr_ =  (uint8_t*)::mmap(NULL, file_size_, PROT_READ|PROT_WRITE, MAP_SHARED, file_ident, 0);
    
    if (mmap_ptr_ == MAP_FAILED) {
        mmap_ptr_ = nullptr;
       
        MXLoggerError("[mxlogger_error]start_mmap error:%s\n",strerror(errno));
        close();
        
        return  false;
    }
    
    return  true;
}

void mmap_sink::flush() {
    async_();
}
bool mmap_sink::msync_(int flag){
    if (msync(mmap_ptr_, get_file_size(), flag) != 0) {
        
        MXLoggerError("[mxlogger_error]msync_ error:%s\n",strerror(errno));
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
