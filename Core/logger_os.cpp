//
//  logger_os.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/16.
//

#include "logger_os.hpp"
#include <sys/types.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <thread>
#include <stdio.h>
#ifndef BLINGLOG_NO_TLS
#    if (defined(_MSC_VER) && (_MSC_VER < 1900)) || defined(__cplusplus_winrt)
#        define SPDLOG_NO_TLS 1
#    endif
#endif

namespace blinglog {
namespace details{
size_t logger_os::thread_id(){
  
    
#if defined(SPDLOG_NO_TLS)
    return _thread_id();
#else // cache thread id in tls
    static thread_local const size_t tid = thread_id_();
    return tid;
#endif
}
size_t logger_os::thread_id_(){

#ifdef _WIN32
    return static_cast<size_t>(::GetCurrentThreadId());
#elif defined(__linux__)
#    if defined(__ANDROID__) && defined(__ANDROID_API__) && (__ANDROID_API__ < 21)
#        define SYS_gettid __NR_gettid
#    endif
    return static_cast<size_t>(::syscall(SYS_gettid));
#elif defined(_AIX)
    struct __pthrdsinfo buf;
    int reg_size = 0;
    pthread_t pt = pthread_self();
    int retval = pthread_getthrds_np(&pt, PTHRDSINFO_QUERY_TID, &buf, sizeof(buf), NULL, &reg_size);
    int tid = (!retval) ? buf.__pi_tid : 0;
    return static_cast<size_t>(tid);
#elif defined(__DragonFly__) || defined(__FreeBSD__)
    return static_cast<size_t>(::pthread_getthreadid_np());
#elif defined(__NetBSD__)
    return static_cast<size_t>(::_lwp_self());
#elif defined(__OpenBSD__)
    return static_cast<size_t>(::getthrid());
#elif defined(__sun)
    return static_cast<size_t>(::thr_self());
#elif __APPLE__
    uint64_t tid;
    pthread_threadid_np(nullptr, &tid);
    return static_cast<size_t>(tid);
#else // Default to standard C++11 (other Unix)
    return static_cast<size_t>(std::hash<std::thread::id>()(std::this_thread::get_id()));
#endif
}
}
}
