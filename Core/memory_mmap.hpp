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
    memory_mmap(const std::string &dir_path);
    ~memory_mmap();
    
   

    bool start_mmap(size_t size);
    
    bool write_data(const std::string &buf,const std::string &fname);
    
private:
    int fd_ = -1;
    
    bool ope_file_();
    bool truncate_(size_t size);
    
    std::string dir_path_;
    
    std::string  filename_;
    
    //一页内存大小
    size_t page_size_;
    // 文件大小
    size_t file_size_;

    size_t position_;
    
    char* mmap_ptr_;
    
};

}


#endif /* memory_mmap_hpp */
