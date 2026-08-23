//
//  mxloger_console.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2023/2/9.
//

#ifndef mxlogger_console_hpp
#define mxlogger_console_hpp

#include <stdio.h>
#include "log_msg.hpp"

/// 控制台输出的编译期开关 MXLOGGER_CONSOLE_ENABLED 定义在 mxlogger_build_config.h，
/// 各平台判据与覆盖方式见那里的说明。
/// The compile-time switch MXLOGGER_CONSOLE_ENABLED lives in mxlogger_build_config.h;
/// see there for the per-platform signals and how to override them.
#include "mxlogger_build_config.h"

namespace mxlogger{
class mxlogger_console{
public:

    static void print(const details::log_msg& msg);
private:
    static std::string gen_console_str(const details::log_msg& msg);

};
}
#endif /* mxlogger_console_hpp */
