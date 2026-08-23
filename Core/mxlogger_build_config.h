//
//  mxlogger_build_config.h
//  MXLoggerCore
//
//  开发期输出(控制台输出 / debug_log)的编译期开关。
//  Compile-time switches for development-time output (console output / debug_log).
//

#ifndef mxlogger_build_config_h
#define mxlogger_build_config_h

/// 这次构建是否保留"开发期输出"。发布构建下相关代码整段不会被编译进产物。
///
/// 各平台判据不同，原因是"谁在什么时候编译这段C++"不一样:
///   * iOS/macOS: pod源码集成，跟着宿主工程编译。Xcode/CocoaPods 只在 Debug 配置定义
///     DEBUG=1，Release/Profile 都不定义 NDEBUG，所以只能用 DEBUG 判定。
///   * Linux/Windows: CMake 的 Release/RelWithDebInfo/MinSizeRel 与 MSVC 的 Release
///     都会定义 NDEBUG(MSVC 的 Debug 定义 _DEBUG，不会命中)。
///   * Android: 发的是预编译 aar，C++ 只在打包时编译一次，那次必然带 -DNDEBUG。若在此裁剪，
///     使用方的 debug 构建也会永久失去输出，因此 Android 一律保留，由运行时开关控制。
///
/// 两个需要显式覆盖的场景:
///   * 想在发布包里保留输出(灰度/QA包): 宿主 target 加 MXLOGGER_CONSOLE_ENABLED=1
///     或 MXLOGGER_DEBUG_LOG_ENABLED=1；
///   * 直接用 clang++/g++ 手搓编译(不带任何配置宏)时，Apple 平台会判定为发布构建而裁掉，
///     需要输出就加 -DDEBUG=1 或单独打开上面两个宏(Core/tests 就是这么做的)。
///
/// Whether this build keeps "development-time output". In release builds the corresponding
/// code is left out of the binary entirely.
///
/// The signal differs per platform because "who compiles this C++, and when" differs:
///   * iOS/macOS: integrated from source via CocoaPods and compiled with the host project.
///     Xcode/CocoaPods only define DEBUG=1 in the Debug configuration and never define
///     NDEBUG, so DEBUG is the only usable signal.
///   * Linux/Windows: CMake's Release/RelWithDebInfo/MinSizeRel and MSVC's Release all
///     define NDEBUG (MSVC's Debug defines _DEBUG instead and does not match).
///   * Android: ships as a prebuilt aar whose C++ is compiled once at packaging time, always
///     with -DNDEBUG. Stripping there would permanently kill the output in the consumer's
///     debug build too, so Android always keeps it and stays runtime-gated.
///
/// Two cases that need an explicit override:
///   * keeping the output in a release build (QA/beta): define MXLOGGER_CONSOLE_ENABLED=1
///     or MXLOGGER_DEBUG_LOG_ENABLED=1 in the host target;
///   * compiling by hand with clang++/g++ without any configuration macro: Apple platforms
///     then look like a release build and strip it — pass -DDEBUG=1, or turn the two
///     switches above on individually (this is what Core/tests does).
#ifndef MXLOGGER_DEV_OUTPUT_ENABLED
    #if defined(__ANDROID__)
        #define MXLOGGER_DEV_OUTPUT_ENABLED 1
    #elif defined(NDEBUG)
        #define MXLOGGER_DEV_OUTPUT_ENABLED 0
    #elif defined(__APPLE__) && !defined(DEBUG) && !defined(_DEBUG)
        #define MXLOGGER_DEV_OUTPUT_ENABLED 0
    #else
        #define MXLOGGER_DEV_OUTPUT_ENABLED 1
    #endif
#endif

/// 控制台输出(mxlogger_console)开关。关闭时 enable_console_ 的判断、gen_console_str、
/// cJSON 解析/打印都不会被编译进产物，set_enable_console 退化为只记标记。
/// Switch for console output (mxlogger_console). When off, the enable_console_ check,
/// gen_console_str and the cJSON parse/print are all left out of the binary, and
/// set_enable_console only records the flag.
#ifndef MXLOGGER_CONSOLE_ENABLED
    #define MXLOGGER_CONSOLE_ENABLED MXLOGGER_DEV_OUTPUT_ENABLED
#endif

/// 库自身诊断输出(debug_log)开关。关闭时 MXLoggerInfo 整条展开为空语句，
/// MXLoggerError 仍会调用并返回错误文案(error_record/errorDesc 依赖它)，只是不输出。
/// Switch for the library's own diagnostics (debug_log). When off, MXLoggerInfo expands to
/// an empty statement, while MXLoggerError is still called and still returns its message
/// (error_record/errorDesc depend on it) — only the printing is skipped.
#ifndef MXLOGGER_DEBUG_LOG_ENABLED
    #define MXLOGGER_DEBUG_LOG_ENABLED MXLOGGER_DEV_OUTPUT_ENABLED
#endif

#endif /* mxlogger_build_config_h */
