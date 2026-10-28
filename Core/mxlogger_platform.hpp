#ifndef MXLOGGER_PLATFORM_HPP
#define MXLOGGER_PLATFORM_HPP

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

#if defined(__APPLE__) && TARGET_OS_OSX
#define MXLOGGER_MACOS_MULTIPROCESS 1
#else
#define MXLOGGER_MACOS_MULTIPROCESS 0
#endif

// Mobile platforms retain their existing single-process file protocol.
#if defined(_WIN32) || MXLOGGER_MACOS_MULTIPROCESS
#define MXLOGGER_MULTIPROCESS 1
#else
#define MXLOGGER_MULTIPROCESS 0
#endif

#endif
