//
//  file_helper.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/4.
//

#ifndef file_helper_hpp
#define file_helper_hpp
#include "logger_common.h"
#include "fmt/os.h"
namespace mxlogger {
namespace details{

class file_helper{
  
public:
    file_helper();
    
    ~file_helper();
    
    //文件名
    void open();
    
    void reopen();
    
    void flush();
    
    void close();
    ///设置保存日志的目录
    void set_dir(const std::string &dir);
    
    //设置文件头
    void set_header(memory_buf_t &header);
    
    void write(const memory_buf_t &buf,const std::string &fname);
    
    // 文件最大存储时间 默认为0 不限制
    void set_max_disk_age(long long max_age);
    
    // 文件最大存储大小 默认为0 不限制
    void set_max_disk_size(long long max_size);
    
    // 删除过期文件
    void remove_expire_data();
    
    // 删除所有日志文件
    void remove_all();
    
    //当前日志文件大小
    long long file_size() const;
    
    std::string &filename() ;
    
private:
    
    bool create_dir_(const std::string &path);
    
    bool path_exists(const std::string &filename);
    
    bool makedir_(const std::string &path);
    
    const int open_tries_ = 5;
    
    std::FILE *fd_{nullptr};
    
    memory_buf_t header_buffer_;
    //文件名
    std::string filename_;
    //文件目录
    std::string dir_;
    
    /// 设置最长存储时间 默认为0 不限制
    long long  max_disk_age_;
    
    /// 设置最大存储限制  默认为0 不限制
    long long max_disk_size_;
    
    
};
}
}



#endif /* file_helper_hpp */
