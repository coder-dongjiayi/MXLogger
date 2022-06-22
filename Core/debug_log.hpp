//
//  debug_log.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/17.
//

#ifndef debug_log_hpp
#define debug_log_hpp

#include <stdio.h>

extern  void _debug_log(int level,const char *filename, const char *func, int line, const char *format, ...);

#   define MXLoggerError(format, ...)                                                                                     \
_debug_log(1,__FILE_NAME__, __func__, __LINE__, format,         \
                          ##__VA_ARGS__)



#   define MXLoggerInfo(format, ...)                                                                                     \
_debug_log(0,__FILE_NAME__, __func__, __LINE__, format,         \
                          ##__VA_ARGS__)


#endif /* debug_log_hpp */
