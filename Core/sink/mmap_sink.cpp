//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#include "mxlogger_helper.hpp"

#include "mxlogger_file_util.hpp"
#include "log_serialize.h"
namespace mxlogger{
namespace sinks{

mmap_sink::mmap_sink(const std::string &dir_path,policy::storage_policy policy,const std::string &file_name){
    
    filename_ = file_name;
    handle_date(policy);
    set_dir(dir_path);
    
    mmap_ =  std::make_shared<memory_mmap>(dir_path,filename_);
    
    
}
void mmap_sink::log(const void* buffer, size_t buffer_size,  level::level_enum level){
   
    if (should_log(level) == false) {
        return;
    }
    
    mmap_ -> write_data(buffer, buffer_size, filename_);
    
    
    
}
void mmap_sink::flush() {
    mmap_ -> sync();
}





};


};
