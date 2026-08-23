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
    char buffer[256];

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

    /// 出错位置: 宏已经把 __FILE_NAME__/__func__/__LINE__ 传进来了，拼进输出和返回值，
    /// 这样 errorDesc 里能直接看到是哪一行报的错
    /// Where it came from: the macro already passes __FILE_NAME__/__func__/__LINE__, so they
    /// are folded into both the output and the return value, which lets errorDesc point at
    /// the exact line that failed
    std::string location = std::string(filename == nullptr ? "?" : filename) + ":" +
                           std::to_string(line) + " " + (func == nullptr ? "?" : func);

    std::string content = "[" + location + "] " + message;

#if MXLOGGER_DEBUG_LOG_ENABLED
#ifdef __ANDROID__
    __android_log_write(level ==0 ? ANDROID_LOG_DEBUG : ANDROID_LOG_ERROR,  info_str.data(), content.c_str());
#else
    /// Apple/Linux/Windows 统一走标准输出。
    /// 注意: iOS上stdout不会进入统一日志系统，flutter run/AndroidStudio控制台抓不到这里的输出，
    /// 原因与 mxlogger_console.cpp 里那段说明相同
    /// Apple/Linux/Windows all go to standard output.
    /// Note: on iOS stdout never reaches the unified logging system, so `flutter run` / the
    /// Android Studio console cannot capture it — same reason as documented in
    /// mxlogger_console.cpp
    printf("%s %s\n",info_str.c_str(), content.c_str());
#endif
#endif

    /// 发布构建下不输出，但返回值必须照常返回: error级别的返回值是 errorDesc 的数据来源
    /// The output is skipped in release builds, but the return value must still be produced:
    /// it is what feeds errorDesc for the error level
    return info_str + content;
}

