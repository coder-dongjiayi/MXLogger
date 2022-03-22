//
//  file_sink.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/5.
//

#ifndef file_sink_hpp
#define file_sink_hpp
#include "sinks.h"
#include <stdio.h>
#include "formatter.hpp"
#include "pattern_formatter.hpp"
#include "file_helper.hpp"
#include "file_appender.hpp"

#include <mutex>
namespace blinglog {
namespace  sinks{

class file_sink final : public sink{
public:
    explicit file_sink();
   
  
    void set_filedir(const std::string &filedir);
    
    void set_file_header(const std::string &header);
    void set_file_policy(policy::storage_policy policy);
    void set_file_name(const std::string &filename);
    
    void set_pattern(const std::string &pattern) final;
    
    
    // 文件最大存储时间 默认为0 不限制
    void set_file_max_disk_age(long long max_age);
    
    // 文件最大存储大小 默认为0 不限制
    void set_file_max_disk_size(long long max_size);
    
    long long file_size() const;
    void remove_all();
    
    void remove_expire_data();
    
    void log(const details::log_msg &msg) override;
    
    void flush() override;
    
   
    
private:
    details::file_helper file_helper_;
    details::file_appender file_appender_;
    
    std::unique_ptr<blinglog::formatter> formatter_;
    
};


}
}

#endif /* file_sink_hpp */
