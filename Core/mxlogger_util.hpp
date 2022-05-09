//
//  mxlogger_util.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/7.
//

#ifndef mxlogger_util_hpp
#define mxlogger_util_hpp

#include <stdio.h>

namespace mxlogger{
namespace util{

class mxlogger_util{
    
public:
    static long select_log_form_path(const char* path,char* result[],long begin,int limit);
    
    
    /// 查询目录下所有的日志文件 按照时间倒xu排列
    /// @param dir 目录
    /// @param result 0 查询成功
    static int select_logfiles_dir(const char* dir,char* result[],int* length);
};

 

};

}




#endif /* mxlogger_util_hpp */
