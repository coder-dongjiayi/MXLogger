//
//  mxlog.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef mxlog_hpp
#define mxlog_hpp
#include <string>
#include <stdio.h>

namespace mxlogger{
namespace sinks {
class console_sink;
class file_sink;
}


class mxlogger{
private:
    
    mxlogger(const char *diskcache_path);
    ~mxlogger();
    
    std::shared_ptr<sinks::console_sink> console_sink_;
   
    std::shared_ptr<sinks::file_sink> file_sink_;
    
    bool enable_;
    bool console_enable_;
    bool file_enable_;
    bool is_debug_tracking_;
    
    static std::string get_diskcache_path_(const char* ns,const char* directory);
    
public:
   

  
    // 初始化 logger
    static mxlogger *initialize_namespace(const char* ns,const char* directory);
    
    /// 释放 logger
    static void delete_namespace(const char* ns,const char* directory);
    
    static std::string md5(const char* ns,const char* directory);
    
    /// 释放全部的logger
    static void destroy();
    
    std::string map_key;
    
    void set_enable(bool enable);
    void set_console_enable(bool enable);
    void set_file_enable(bool enable);
    
    
    void set_file_policy(const char* policy);
    
    
     void set_file_name(const char* filename);
    
    
     void set_file_header(const char* header);
    
    
    // 设置日志文件最大字节数(byte)
    void set_file_max_size(const  long max_size);
    
    // 设置日志文件最大存储时长(s)
    void set_file_max_age(const  long max_age);
    
    // 清理过期文件
    void remove_expire_data();
    
    //删除所有日志文件
    void remove_all();
    
    // 缓存日志文件大小(byte)
    long  file_size();
    
    void set_console_level(int level);
    
    void set_file_level(int level);
    
    void set_console_pattern(const char * pattern);
    
    void set_file_pattern(const char * pattern);
    
    const char* diskcache_path() const;
    
    const bool is_debug_tracking();
   
    /// 记录日志
    /// @param type 1 输出到控制台 2 写入文件 0 先输出到控制台再写入文件
    /// @param level 0 debug 1 info 2warn 3 error 4 fatal
    /// @param name 默认值  mxlogger
    /// @param msg 日志信息
    /// @param tag 标记
    /// @param is_main_thread 是否在主线程
    void log(int type, int level,const char* name, const char* msg,const char* tag,bool is_main_thread);
private:
    std::string diskcache_path_;
  
};


}

using mx_logger = typename mxlogger::mxlogger;
#endif /* mxlog_hpp */
