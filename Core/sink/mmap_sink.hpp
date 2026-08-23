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
#ifndef _WIN32
#include <unistd.h>
#endif
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

#ifdef _WIN32
    // Windows的文件映射对象(CreateFileMapping)，与映射视图配对管理
    void* file_mapping_ = nullptr;
#endif

    int write_data_(const void* buffer, size_t buffer_size);

    /// 建立(或恢复)文件映射：fd丢失时重开文件，空文件先做页对齐扩容，
    /// 成功后从文件头恢复actual_size_；构造和写入自愈共用此路径
    /// Establish (or recover) the file mapping: reopen the file when the fd is lost,
    /// page-align an empty file first, and restore actual_size_ from the file header
    /// on success; shared by the constructor and the write-time self-healing path
    bool recover_mmap_();

    int truncate_(size_t size);

    bool mmap_();
    bool munmap_();

    size_t get_actual_size_();

    void write_actual_size_(size_t size);
    int log_(const details::log_msg& msg);

    /// is_sync为true同步刷盘，false异步
    bool msync_(bool is_sync);
     bool sync_();

     bool async_();
     
    
};



}
}
#endif /* mmap_sink_hpp */
