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
    
    std::shared_ptr<sinks::console_sink> console_sink_;
   
    
    std::shared_ptr<sinks::file_sink> file_sink_;
    
public:
    mxlogger(const char *diskcache_path);
    ~mxlogger();

    void set_enable(bool enable);
    void set_console_enable(bool enable);
    void set_file_enable(bool enbale);
    
    
    
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


#endif /* mxlog_hpp */
