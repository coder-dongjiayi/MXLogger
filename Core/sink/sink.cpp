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
    return true;
}
level::level_enum  sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}
void sink::init_aescfb(const char* crypt_key,const char* crypt_iv){
    
    if (crypt_key == nullptr) {
        return;
    }
//    std::pair<uint8_t*, uint8_t*> aes = mxlogger_helper::generate_crypt_key(crypt_key, crypt_iv);
//
//    memcpy(crypt_key_, aes.first, 16);
//
//    memcpy(crypt_iv_, aes.second, 16);

   
}

}
}
