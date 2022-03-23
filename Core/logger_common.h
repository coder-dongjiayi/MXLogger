//
//  logger_common.h
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#pragma once


#include <atomic>

#include <stdio.h>
#include <chrono>

#include "fmt/chrono.h"
#include "fmt/format.h"
#include "logger_enum.h"
namespace mxlogger {
namespace sinks{
class sink;
};

using sink_ptr = std::shared_ptr<sinks::sink>;

using log_clock = std::chrono::system_clock;

using sinks_init_list = std::initializer_list<sink_ptr>;

}

static const char *default_eol = "\n";

namespace fmt_lib = fmt;


using string_view_t = fmt::basic_string_view<char>;
using memory_buf_t  = fmt::basic_memory_buffer<char,5>;

using log_clock = std::chrono::system_clock;

template<typename  T,typename... Args>

std::unique_ptr<T> make_unique(Args &&... args){
    
    static_assert(!std::is_array<T>::value, "arrays not supported");
    return  std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}



// 存储当前等级信息
using level_t =  std::atomic_int;

static const char *level_names[]{"DEBUG","INFO","WARN","ERROR","FATAL"};




