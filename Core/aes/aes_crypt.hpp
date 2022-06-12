

#ifndef AES_CRYPT_H_
#define AES_CRYPT_H_
#ifdef __cplusplus


#include <cstddef>
#include<stdint.h>


namespace openssl {
struct AES_KEY;
}

constexpr size_t AES_KEY_LEN = 16;
constexpr size_t AES_KEY_BITSET_LEN = 128;

namespace mxlogger {

class aes_crypt {
private:
    uint8_t m_vector[AES_KEY_LEN] = {};
    uint8_t m_key[AES_KEY_LEN] = {};
    
    uint32_t m_number = 0;
    openssl::AES_KEY *m_aesKey = nullptr;
  
   

public:
    aes_crypt();

    ~aes_crypt();

    void set_crypt_key(const void *key, size_t keyLength,  void *iv , size_t ivLength );
    
    void encrypt(const void *input, void *output, size_t length);

    void decrypt(const void *input, void *output, size_t length);

    void reset_iv(const void *iv = nullptr, size_t ivLength = 0);


};

}

#endif
#endif

