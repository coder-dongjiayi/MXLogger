//
//  file_helper.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/4.
//

#ifndef file_helper_hpp
#define file_helper_hpp

#include <string>
namespace mxlogger {
namespace details{

class mx_file{
  
public:
    mx_file();
    
    ~mx_file();
    
    //文件名
    void open();
    
    void reopen();
    
    void flush();
    
    void close();
    ///设置保存日志的目录
    void set_dir(const std::string dir);
    
    //设置文件头
    void set_header(std::string header);
    
    void write(const std::string &buf,const std::string &fname);
    
    // 文件最大存储时间 默认为0 不限制
    void set_max_disk_age(long long max_age);
    
    // 文件最大存储大小 默认为0 不限制
    void set_max_disk_size(long long max_size);
    
    // 删除过期文件
    void remove_expire_data();
    
    // 删除所有日志文件
    void remove_all();
    
    //当前目录下的文件大小
    long  dir_size() const;
    
    std::string &filename() ;
    
private:
    
    bool create_dir_(const std::string &path);
    
    
    const int open_tries_ = 5;
    
    std::FILE *fd_{nullptr};
    
    std::string header_buffer_;
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
