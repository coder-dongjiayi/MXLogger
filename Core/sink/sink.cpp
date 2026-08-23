//
//  sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "sink.hpp"
#include "mxlogger_helper.hpp"
#include<stdint.h>

namespace mxlogger{
namespace sinks{
void sink::set_level(level::level_enum log_level){
     level_.store(log_level,std::memory_order_relaxed);
}

bool sink::should_log(level::level_enum msg_level){
    return  msg_level >= level_.load(std::memory_order_relaxed);
}

bool sink::should_encrypt(){
    return is_aes;
}
level::level_enum  sink::level() const{
    return static_cast<level::level_enum>(level_.load(std::memory_order_relaxed));
}
void sink::init_aescfb(const char* crypt_key,const char* crypt_iv){

    if (crypt_key == nullptr) {
        return;
    }

    size_t iv_length = crypt_iv == nullptr ? 0 : strlen(crypt_iv);
    if (iv_length > 0) {
        // iv_ 默认全零，不足16字节的iv自动补零，超出截断
        memcpy(iv_, crypt_iv, iv_length > AES_KEY_LEN ? AES_KEY_LEN : iv_length);
        has_iv_ = true;
    }

    is_aes = true;
    crypt_.set_crypt_key(crypt_key, strlen(crypt_key), (void*)crypt_iv, iv_length);


}
void sink::cfb128_encrypt(const void *input, void *output, size_t length){

    crypt_.encrypt(input, output, length);

    // 每条日志独立加密，必须用补零后的完整16字节恢复向量
    // 按strlen恢复会让短iv的向量尾部残留上一条密文，导致解析端无法解密
    crypt_.reset_iv(has_iv_ ? iv_ : nullptr, has_iv_ ? AES_KEY_LEN : 0);

}

}
}
