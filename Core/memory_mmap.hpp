//
//  memory_mmap.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#ifndef memory_mmap_hpp
#define memory_mmap_hpp
#include <stdlib.h>
#include <stdio.h>
#include <string>
namespace  mxlogger{
class memory_mmap{
  
public:
    memory_mmap(const std::string &dir_path,const std::string &fname);
    ~memory_mmap();
    
   

    bool sync();
    
    bool async();
    
    bool mmap();
    
    void write_actual_size(size_t size);
   
    size_t get_actual_size();
    
    bool write_data(const std::string &buf,const std::string &fname);
    
    bool write_data2(const void* buffer, size_t buffer_size, const std::string &fname);
    
private:
    int fd_ = -1;
    
    bool ope_file_();
    bool truncate_(size_t size);
    bool msync_(int flag);
    
    std::string mmap_disk_path_;
    
    /// 文件目录
    std::string dir_path_;
    
    
    /// 文件名
    std::string  filename_;
    
    //一页内存大小
    size_t page_size_ = 0;
    // 文件大小
    size_t file_size_ = 0;

    
    uint8_t* mmap_ptr_ = nullptr;
    
    //文件真实大小
    size_t actual_size_ = 0;
    

    
};

}


#endif /* memory_mmap_hpp */
