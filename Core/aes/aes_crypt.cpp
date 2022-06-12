
#include "aes_crypt.hpp"
#include "openssl/openssl_aes.h"
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <stdio.h>

using namespace openssl;

namespace mxlogger {

aes_crypt::aes_crypt() {
   
}

aes_crypt::~aes_crypt() {
    delete m_aesKey;
}

void aes_crypt::set_crypt_key(const void *key, size_t keyLength,  void *iv , size_t ivLength){
    if (key && keyLength > 0) {
        memcpy(m_key, key, (keyLength > AES_KEY_LEN) ? AES_KEY_LEN : keyLength);

        reset_iv(iv, ivLength);

        m_aesKey = new AES_KEY;
        memset(m_aesKey, 0, sizeof(AES_KEY));
        int ret = AES_set_encrypt_key(m_key, AES_KEY_BITSET_LEN, m_aesKey);
        if (ret != 0) {
            printf("[mxlogger_error]AES_set_encrypt_key error :%d\n",ret);
        }
      
    }
}
void aes_crypt::reset_iv(const void *iv, size_t ivLength) {
    m_number = 0;
    if (iv && ivLength > 0) {
        memcpy(m_vector, iv, (ivLength > AES_KEY_LEN) ? AES_KEY_LEN : ivLength);
    } else {
        memcpy(m_vector, m_key, AES_KEY_LEN);
    }
}


void aes_crypt::encrypt(const void *input, void *output, size_t length) {
    if (!input || !output || length == 0) {
        return;
    }
    AES_cfb128_encrypt((const uint8_t *) input, (uint8_t *) output, length, m_aesKey, m_vector, &m_number);
}

void aes_crypt::decrypt(const void *input, void *output, size_t length) {
    if (!input || !output || length == 0) {
        return;
    }
    AES_cfb128_decrypt((const uint8_t *) input, (uint8_t *) output, length, m_aesKey, m_vector, &m_number);
}


}
