//
//  file_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/14.
//

#include "file_sink.hpp"
namespace mxlogger{

namespace sinks{
void file_sink::log(const details::log_msg &msg){
    if (should_log(msg.level) == false) return;
    std:: string formatted;
    
    formatter_ -> format(msg, formatted);
    
    mxfile -> write(formatted, file_appender_.calc_filename());
    
    mxfile-> flush();
    
}

void file_sink::set_pattern(const std::string &pattern){
    formatter_ =  std::unique_ptr<mxlogger::pattern_formatter>(new mxlogger::pattern_formatter(pattern));
}



void file_sink::flush() {
    
}
};

};
