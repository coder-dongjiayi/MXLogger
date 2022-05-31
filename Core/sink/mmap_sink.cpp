//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#include "mxlogger_helper.hpp"
#include "../cJson/cJSON.h"
#include "mxlogger_file_util.hpp"
namespace mxlogger{
namespace sinks{

mmap_sink::mmap_sink(const std::string &dir_path,policy::storage_policy policy){
    
    handle_date(policy);
    mmap_ =  std::make_shared<memory_mmap>(dir_path);
    
}
void mmap_sink::log(const details::log_msg &msg){
   
    if (should_log(msg.level) == false) {
        return;
    }
  
    mmap_->write_data(msg.json_string.data(),filename_);
    
    
}
void mmap_sink::flush() {
   
}





};


};
