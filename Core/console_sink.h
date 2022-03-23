//
//  console_sink.hpp
//  Logger
//
//  Created by 董家祎 on 2022/2/24.
//

#pragma once

#include <stdio.h>
#include "sinks.h"

#include "formatter.hpp"

namespace mxlogger{
namespace sinks{

class console_sink : public sink{
    
public:

    console_sink(FILE *target_file);
    
    ~console_sink() override = default;
    
    void log(const details::log_msg &msg) override;
    
    void set_pattern(const std::string &pattern) final;
    
    void flush() override;
    
private:
    FILE *target_file_;
    
    std::string pattern_;
    
    std::unique_ptr<mxlogger::formatter> formatter_;
    
    //打印输出
    void print_range_(const memory_buf_t &formatted,size_t start,size_t end);

};

}
}

