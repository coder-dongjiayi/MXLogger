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
namespace mxlogger{
class mxlogger_console{
public:

    static void print(const details::log_msg& msg);
private:
    static std::string gen_console_str(const details::log_msg& msg);

};
}
#endif /* mxlogger_console_hpp */
