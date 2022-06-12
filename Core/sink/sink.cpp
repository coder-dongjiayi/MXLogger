//
//  sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "sink.hpp"
#include "mxlogger_helper.hpp"

namespace mxlogger{
namespace sinks{
void sink::set_level(level::level_enum log_level){
     level_.store(log_level,std::memory_order_relaxed);
}

bool sink::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}

bool sink::should_encrypt(){
    return crypt_key_ != nullptr;
}
level::level_enum  sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}
void sink::init_aescfb(const char* crypt_key,const char* crypt_iv){
    
    if (crypt_key == nullptr) {
        return;
    }

    crypt_iv_ = crypt_iv;
    crypt_key_ = crypt_key;
    crypt_.set_crypt_key(crypt_key, strlen(crypt_key), (void*)crypt_iv, strlen(crypt_iv));

   
}
void sink::cfb128_encrypt(const void *input, void *output, size_t length){
 
    crypt_.encrypt(input, output, length);
    crypt_.reset_iv(crypt_iv_,strlen(crypt_iv_));
   
}

}
}
