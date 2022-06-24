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
#include <mutex>

namespace mxlogger{
namespace sinks {

class mmap_sink;
}


class mxlogger{
private:
    
    mxlogger(const char *diskcache_path,const char* storage_policy,const char* file_name, const char* cryptKey, const char* iv);
    ~mxlogger();
    
    
    std::shared_ptr<sinks::mmap_sink> mmap_sink_;
    
    bool enable_;
    bool enable_console_;
    
    
    std::mutex logger_mutex;
    
    static std::string get_diskcache_path_(const char* ns,const char* directory);
    
    std::string diskcache_path_;

    
        
public:
   

  
    // 初始化 logger
    static mxlogger *initialize_namespace(const char* ns,const char* directory,const char* storage_policy,const char* file_name,const char* cryptKey, const char* iv);
    
    /// 释放 logger
    static void delete_namespace(const char* ns,const char* directory);
    
    static std::string md5(const char* ns,const char* directory);
    
    /// 释放全部的logger
    static void destroy();
    

    std::string map_key;
    

    // 是否开启日志
    void set_enable(bool enable);
    // 是否开启控制台输出
    void set_enable_console(bool enable);
    
    // 设置日志文件最大字节数(byte)
    void set_file_max_size(const  long max_size);
    
    // 设置日志文件最大存储时长(s)
    void set_file_max_age(const  long max_age);
    
    // 清理过期文件
    void remove_expire_data();
    
    //删除所有日志文件
    void remove_all();
    
    // 缓存日志文件大小(byte)
    long  dir_size();
    
    // 设置日志存储等级
    void set_file_level(int level);
    
    
    void flush();
    
    // 返回日志的磁盘路径
    const char* diskcache_path() const;
    
   
    /// 记录日志
  
    /// @param level 0 debug 1 info 2warn 3 error 4 fatal
    /// @param name 默认值  mxlogger
    /// @param msg 日志信息
    /// @param tag 标记
    /// @param is_main_thread 是否在主线程
    void log(int level,const char* name, const char* msg,const char* tag,bool is_main_thread);

   
  
};


}

using mx_logger = typename mxlogger::mxlogger;
#endif /* mxlog_hpp */
