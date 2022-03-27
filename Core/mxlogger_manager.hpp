//
//  logger_manager.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/8.
//

#ifndef mxlogger_manager_hpp
#define mxlogger_manager_hpp


#include <string>

#include "logger_enum.h"


namespace mxlogger{

namespace sinks{
class file_sink;
}
class logger;
class async_logger;
class thread_pool;

enum log_type : int {
    console = 0,
    file = 1,
    all = 2,
};



class mxlogger_manager {
    
private:
    mxlogger_manager();
    ~mxlogger_manager();
    
    std::shared_ptr<mxlogger::logger> console_logger_;
    std::shared_ptr<mxlogger::async_logger> async_file_logger_;
    std::shared_ptr<mxlogger::logger> sync_file_logger_;

    std::shared_ptr<thread_pool> tp_;
    
    
    inline  sinks::file_sink *async_file_sink_();
    inline sinks::file_sink *sync_file_sink_();
    
    bool enable_;
    bool console_enable_;
    bool file_enable_;
    bool debug_traceing_;
    
    // 日志写入是否为异步 默认为YES
    bool is_async_;
    
    void log_console_(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
    
    void log_file_(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
    
    void log_it_(log_type type,level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
    
public:
    static mxlogger_manager &instance();

    
    /* 设置日志文件存储策略和文件名
      默认存储策略：yyyy_MM_dd (每天生成一个日志文件)
      默认文件名: mxlog.log

     */
    
    void set_file_policy(policy::storage_policy policy);
    
    void set_file_name(const char* filename);
    
    /*
    设置每次创建一个新文件的时候都会写入一个文件头，比如可以存储当前设备、登录用户的一些基本信息
     */
    void set_file_header(const char* header);
    
    // 开启和禁用日志功能(包括控制台打印和文件存储)
    void set_enable(const bool enable);
    
    // 是否禁用控制台打印
    void set_console_enable(const bool enable);
    // 是否禁用文件存储
    void set_file_enable(const bool enable);
    
    // 设置保存日志文件的目录
    void set_file_dir(const std::string &filedir);
    
    // 设置日志文件最大字节数(byte)
    void set_file_max_size(const long long max_size);
    
    // 设置日志文件最大存储时长(s)
    void set_file_max_age(const long long max_age);
    
    // 清理过期文件
    void remove_expire_data();
    
    //删除所有日志文件
    void remove_all();
    
    // 缓存日志文件大小(byte)
    long  file_size();
    
    // 是否正在被调试
    bool is_debuging() const;
    
    void set_file_async(bool is_async);
    
    void set_console_level(level::level_enum lvl);
    
    void set_file_level(level::level_enum lvl);
    
    void set_console_pattern(const std::string &pattern);
    
    void set_file_pattern(const std::string &pattern);
    
    void log_all(level::level_enum lvl,const char* prefix,const char* msg,const char* tag,bool is_main_thread);
    
    void log(log_type type,level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
    
    
    void log_async_file(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
   
    void log_sync_file(level::level_enum lvl,const char* name,const char* msg,const char* tag,bool is_main_thread);
    
};

}

using mx_logger = mxlogger::mxlogger_manager;


#endif /* logger_manager_hpp */
