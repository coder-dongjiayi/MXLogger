//
//  test_aes_crypt.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 aes_crypt: 加解密round-trip、key/iv补零与截断语义、iv回退、向量重置
//

#include "mx_test.hpp"
#include "aes/aes_crypt.hpp"
#include <cstring>

using mxlogger::aes_crypt;

static std::string enc(aes_crypt& c, const std::string& plain) {
    std::string out(plain.size(), '\0');
    c.encrypt(plain.data(), &out[0], plain.size());
    return out;
}
static std::string dec(aes_crypt& c, const std::string& cipher) {
    std::string out(cipher.size(), '\0');
    c.decrypt(cipher.data(), &out[0], cipher.size());
    return out;
}

MX_TEST(aes_crypt, roundtrip_various_lengths) {
    const char* key = "0123456789abcdef";
    const char* iv  = "fedcba9876543210";

    // CFB是流模式，任意长度(含非16倍数)都应round-trip
    for (size_t len : {(size_t)1, (size_t)15, (size_t)16, (size_t)17, (size_t)100, (size_t)1000}) {
        std::string plain(len, '\0');
        for (size_t i = 0; i < len; i++) plain[i] = (char)('a' + i % 26);

        aes_crypt encryptor;
        encryptor.set_crypt_key(key, 16, (void*)iv, 16);
        std::string cipher = enc(encryptor, plain);
        EXPECT_TRUE(cipher != plain);

        aes_crypt decryptor;
        decryptor.set_crypt_key(key, 16, (void*)iv, 16);
        EXPECT_EQ(dec(decryptor, cipher), plain);
    }
}

MX_TEST(aes_crypt, short_key_zero_padded) {
    // 短key语义 = 补零到16字节的key
    const char* short_key = "abc";
    char padded_key[16] = {'a', 'b', 'c'};
    const char* iv = "fedcba9876543210";
    std::string plain = "the quick brown fox";

    aes_crypt a, b;
    a.set_crypt_key(short_key, 3, (void*)iv, 16);
    b.set_crypt_key(padded_key, 16, (void*)iv, 16);
    EXPECT_EQ(enc(a, plain), enc(b, plain));
}

MX_TEST(aes_crypt, long_key_truncated) {
    // 超长key语义 = 截断到前16字节
    const char* long_key = "0123456789abcdefEXTRA";
    const char* key16 = "0123456789abcdef";
    const char* iv = "fedcba9876543210";
    std::string plain = "truncate me";

    aes_crypt a, b;
    a.set_crypt_key(long_key, strlen(long_key), (void*)iv, 16);
    b.set_crypt_key(key16, 16, (void*)iv, 16);
    EXPECT_EQ(enc(a, plain), enc(b, plain));
}

MX_TEST(aes_crypt, no_iv_falls_back_to_key) {
    // 不传iv时，约定用key本身当iv
    const char* key = "0123456789abcdef";
    std::string plain = "fallback iv";

    aes_crypt a, b;
    a.set_crypt_key(key, 16, nullptr, 0);
    b.set_crypt_key(key, 16, (void*)key, 16);
    EXPECT_EQ(enc(a, plain), enc(b, plain));
}

MX_TEST(aes_crypt, reset_iv_restores_stream) {
    // reset_iv后重新加密同一明文，密文应与首次完全一致
    const char* key = "0123456789abcdef";
    const char* iv = "fedcba9876543210";
    std::string plain = "repeatable message";

    aes_crypt c;
    c.set_crypt_key(key, 16, (void*)iv, 16);
    std::string first = enc(c, plain);
    std::string second_no_reset = enc(c, plain);
    EXPECT_TRUE(first != second_no_reset); // 不重置时流继续演化

    c.reset_iv(iv, 16);
    EXPECT_EQ(enc(c, plain), first);
}

MX_TEST(aes_crypt, set_crypt_key_twice_no_crash) {
    // 重复设置key(内部会释放旧AES_KEY)，行为以最后一次为准
    const char* iv = "fedcba9876543210";
    std::string plain = "rekey";

    aes_crypt a;
    a.set_crypt_key("first_key_111111", 16, (void*)iv, 16);
    a.set_crypt_key("second_key_22222", 16, (void*)iv, 16);

    aes_crypt b;
    b.set_crypt_key("second_key_22222", 16, (void*)iv, 16);
    EXPECT_EQ(enc(a, plain), enc(b, plain));
}

MX_TEST(aes_crypt, null_input_safe) {
    aes_crypt c;
    c.set_crypt_key("0123456789abcdef", 16, nullptr, 0);
    char buf[8] = {};
    // 空指针/零长度直接返回，不崩溃
    c.encrypt(nullptr, buf, 8);
    c.decrypt(buf, nullptr, 8);
    c.encrypt(buf, buf, 0);
    EXPECT_TRUE(true);
}
