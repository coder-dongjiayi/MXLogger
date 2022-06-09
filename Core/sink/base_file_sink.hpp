//
//  base_file_sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/8.
//

#ifndef base_file_sink_hpp
#define base_file_sink_hpp

#include <stdio.h>
#include "sink.hpp"
namespace mxlogger{
namespace sinks {
class base_file_sink : public sink{
    
private:
    /// 设置最长存储时间 默认为0 不限制
    long long  max_disk_age_ = 0;
    
    /// 设置最大存储限制  默认为0 不限制
    long long max_disk_size_ = 0;
    
    /// 文件夹路径
    std::string dir_path_;
    

    
    policy::storage_policy policy_;
    
protected:
    
    /// 日志文件名称
    std::string filename_;
    
    /// 完整的日志路径 dir_path_ + filename_
    std::string log_disk_path_;
    
    ///file_name 文件名
    bool open(const std::string &filename);
    
    
    void handle_date(policy::storage_policy policy);
    
    int file_ident = -1;
    
    // 获取文件大小
    size_t get_file_size();
    
    /// 文件扩容
    bool ftruncate(size_t capacity_size);
    
    void close();
    
public:
     base_file_sink(const std::string &dir_path,policy::storage_policy policy);
    ~base_file_sink();
    //当前目录下的文件大小
    long  dir_size() const;
    
    void set_dir(const std::string &dir_path);
    
    // 文件最大存储时间 默认为0 不限制
    void set_max_disk_age(long long max_age);
    
    // 文件最大存储大小 默认为0 不限制
    void set_max_disk_size(long long max_size);
    
    // 删除过期文件
    void remove_expire_data();
    
    // 删除所有日志文件
    void remove_all();
    
};
}
}

#endif /* base_file_sink_hpp */
