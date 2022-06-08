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
#include "log_serialize.h"
namespace mxlogger{
namespace sinks{

mmap_sink::mmap_sink(const std::string &dir_path,policy::storage_policy policy,const std::string &file_name){
    
    filename_ = file_name;
    handle_date(policy);
    
    mmap_ =  std::make_shared<memory_mmap>(dir_path,filename_);
    
    
}
void mmap_sink::log(const details::log_msg &msg){
   
    if (should_log(msg.level) == false) {
        return;
    }
    flatbuffers::FlatBufferBuilder builder_;
    auto root = mxlogger::Createlog_serializeDirect(builder_,"name","net","第1条数据",1,1,1654501033228);

    builder_.Finish(root);
    
     mmap_ -> write_data2(builder_.GetBufferPointer(), builder_.GetSize(), filename_);
   
    
  //  mmap_->write_data(msg.json_string.data(),filename_);
    
    
}
void mmap_sink::flush() {
   
}





};


};
