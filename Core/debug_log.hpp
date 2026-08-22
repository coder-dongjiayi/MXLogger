//
//  debug_log.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/17.
//

#ifndef debug_log_hpp
#define debug_log_hpp

#include <stdio.h>
#include <string>
#include "mxlogger_build_config.h"

/// __FILE_NAME__ 是clang扩展(GCC 12+/MSVC没有)，其他编译器回退用完整路径
#ifndef __FILE_NAME__
#define __FILE_NAME__ __FILE__
#endif

extern  std::string _debug_log(int level,const char *filename, const char *func, int line, const char *format, ...);

/// error级别始终调用: 12处调用点把返回值接给了sink的error_record，
/// 最终通过 mxlogger::error_desc() 暴露给 OC/Java/Dart 的 errorDesc，禁掉会让错误信息变空串。
/// MXLOGGER_DEBUG_LOG_ENABLED 只控制"要不要打印"，不影响返回值。
/// The error level is always evaluated: 12 call sites assign its return value to the sink's
/// error_record, which is exposed through mxlogger::error_desc() as errorDesc on the
/// OC/Java/Dart side — dropping it would blank out the error message.
/// MXLOGGER_DEBUG_LOG_ENABLED only controls whether it is printed, never the return value.
#   define MXLoggerError(format, ...)                                                                                     \
_debug_log(1,__FILE_NAME__, __func__, __LINE__, format,         \
                          ##__VA_ARGS__)


/// info级别的返回值16处调用点全部丢弃，因此发布构建下整条展开为空语句，
/// 连实参求值和函数调用都不会发生(所有实参都是 c_str()/size()/局部变量这类无副作用表达式)。
/// The info level's return value is discarded at all 16 call sites, so in release builds it
/// expands to an empty statement — not even the arguments are evaluated (they are all
/// side-effect-free expressions such as c_str()/size()/locals).
#if MXLOGGER_DEBUG_LOG_ENABLED
#   define MXLoggerInfo(format, ...)                                                                                     \
_debug_log(0,__FILE_NAME__, __func__, __LINE__, format,         \
                          ##__VA_ARGS__)
#else
#   define MXLoggerInfo(format, ...) ((void)0)
#endif


#endif /* debug_log_hpp */
