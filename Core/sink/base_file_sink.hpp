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
    
    std::string dir_path_;
    
public:
    
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
