//
//  mxloger_console.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2023/2/9.
//

#include "mxlogger_console.hpp"
#include <sstream>
#include <iomanip>
#include "log_enum.h"
#include "mxlogger_helper.hpp"
#ifdef  __ANDROID__
#include <android/log.h>
#endif
#include "json/cJSON.h"
namespace mxlogger{

#if MXLOGGER_CONSOLE_ENABLED

void mxlogger_console::print(const details::log_msg& msg){

    std::string console = gen_console_str(msg);
    #ifdef __ANDROID__
            android_LogPriority priority;
            switch (msg.level) {
                case level::level_enum::debug:
                    priority = ANDROID_LOG_DEBUG;
                    break;
                case level::level_enum::info:
                    priority = ANDROID_LOG_INFO;
                    break;
                case level::level_enum::warn:
                    priority = ANDROID_LOG_WARN;
                    break;
                case level::level_enum::error:
                    priority = ANDROID_LOG_ERROR;
                    break;
                case level::level_enum::fatal:
                    priority = ANDROID_LOG_FATAL;
                    break;
                default:
                    priority = ANDROID_LOG_DEBUG;
                    break;
    
            }
        console.append("\0");
            /// tag可能为nullptr(调用方未传tag)，liblog内部会对tag做strlen，必须兜底
            /// tag may be nullptr when the caller passes none; liblog runs strlen on it
            /// internally, so a fallback is required
            __android_log_write(priority,  msg.tag == nullptr ? "mxlogger" : msg.tag, console.c_str());
    #else

    /// Apple/Linux/Windows 统一走标准输出。
    /// 注意: iOS上stdout不会进入统一日志系统，flutter run/AndroidStudio控制台抓不到这里的输出
    /// (换成os_log也不行，flutter工具的模拟器日志谓词只放行sender为Flutter.framework或App主二进制的日志，
    ///  MXLoggerCore作为动态framework会被过滤掉)，所以flutter插件侧不开启native控制台，改由dart层debugPrint输出。
    /// Apple/Linux/Windows all go to standard output.
    /// Note: on iOS stdout never reaches the unified logging system, so `flutter run` /
    /// the Android Studio console cannot capture it (os_log does not help either: the
    /// flutter tool's simulator predicate only accepts logs whose sender image is
    /// Flutter.framework or the app's own executable, and MXLoggerCore is a dynamic
    /// framework). The Flutter plugin therefore keeps the native console disabled and
    /// prints from the Dart layer instead.
    printf("%s", console.data());
    #endif
   
}

std::string mxlogger_console:: gen_console_str(const details::log_msg& msg){
    
    
    constexpr auto width = 100U;
    
    std::string time = mxlogger_helper::micros_datetime(msg.now_time);
    
    std::basic_ostringstream<char> stream;
    
    char sep = '-';
    
    std::string string_msg = msg.msg != nullptr ?  msg.msg : "";
    cJSON * jsonItem = cJSON_Parse(msg.msg);
    char* jsonStr = nullptr;
    
    if(jsonItem != nullptr){
        jsonStr = cJSON_Print(jsonItem);
    }
    cJSON_Delete(jsonItem);
    if(jsonStr != nullptr){
        string_msg = jsonStr;
    }
    /// cJSON_Print返回的是malloc分配的内存，不能用delete释放
    cJSON_free(jsonStr);
    
    std::string thread =  std::to_string(msg.thread_id)  + ":"+ (msg.is_main_thread == true ? "main" : "child");
    
    std::string level = std::string{level_names[msg.level]};
  

    stream << std::endl;
    
    
    for (size_t i = 0; i != width; ++i)
    {
        if(i == width / 2){
            stream << "MXLogger";
        }
            
        stream << sep;
    }
    
    stream << std::endl;
    
    // center

    stream << " time : " << time <<" [" + thread + "]" << endl;
    
    stream << " level: " + level << " " << level_icons[msg.level] << std::endl;
    
    /// name同样可能为nullptr，std::string不接受空指针构造
    /// name may also be nullptr, and std::string cannot be constructed from one
    stream << " name : " + std::string{msg.name == nullptr ? "" : msg.name} <<std::endl;
   
    if(msg.tag != nullptr){
        stream << " tags : " + std::string{msg.tag} << std::endl;
    }
   
    stream  << " msg  : " <<string_msg << std::endl;
   
    
    // bottom
    for (size_t i = 0; i != (width + 8); ++i)
    {
        stream << sep;
    }
    stream << std::endl;
    
    return stream.str();
}

#else

/// 编译期关闭时保留空实现: OC的consoleEnable/JNI/flutter bridge都还引用着这条链路，
/// 符号必须存在，否则ABI断裂；调用点已在mxlogger.cpp里整段裁掉，这里不会被执行到。
/// Keep empty definitions when the console is compiled out: the OC consoleEnable property,
/// the JNI bridge and the flutter bridges all still reference this path, so the symbols must
/// remain or the ABI breaks. The call site itself is stripped in mxlogger.cpp, so these are
/// never reached.
void mxlogger_console::print(const details::log_msg& msg){
    (void)msg;
}

std::string mxlogger_console::gen_console_str(const details::log_msg& msg){
    (void)msg;
    return {};
}

#endif

}

