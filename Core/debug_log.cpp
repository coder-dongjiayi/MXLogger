//
//  debug_log.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/17.
//

#include "debug_log.hpp"
#include <string>
#ifdef  __ANDROID__
#include <android/log.h>
#endif
std::string _debug_log(int level, const char *filename, const char *func, int line, const char *format, ...){
 
    
    std::string message;
    char buffer[16];

    va_list args;
    va_start(args, format);
    auto length = std::vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);

    if (length < 0) {
        message = {};
    } else if (length < sizeof(buffer)) {
        message = std::string(buffer, static_cast<unsigned long>(length));
    } else {
        message.resize(static_cast<unsigned long>(length), '\0');
        va_start(args, format);
        std::vsnprintf(const_cast<char *>(message.data()), static_cast<size_t>(length) + 1, format, args);
        va_end(args);
    }
    std::string info_str = level == 0 ? "[mxlogger_info]" : "[mxlogger_error]";
#ifdef __ANDROID__
    __android_log_write(level ==0 ? ANDROID_LOG_DEBUG : ANDROID_LOG_ERROR,  info_str.data(), message.c_str());
#elif __APPLE__
    printf("%s %s\n",info_str.c_str(), message.c_str());
#endif

    return info_str + message;
}

