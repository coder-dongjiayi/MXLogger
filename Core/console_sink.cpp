//
//  console_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "console_sink.hpp"

namespace mxlogger{

namespace sinks{

console_sink::console_sink(FILE * target_file):  target_file_(target_file){

}
void console_sink::log(const details::log_msg &msg)
{
 
    if (should_log(msg.level) == false) return;
    
    std:: string formatted;
    
    formatter_ -> format(msg, formatted);
    
   const char * ptr = formatted.data();

    size_t length = formatted.length();
    
    fwrite(ptr, sizeof(char), length, target_file_);
}

void console_sink::flush(){
  
    fflush(target_file_);
}


void console_sink::set_pattern(const std::string &pattern){
   
   formatter_ =  std::unique_ptr<mxlogger::pattern_formatter>(new mxlogger::pattern_formatter(pattern));
};

};
};
