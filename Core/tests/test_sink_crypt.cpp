//
//  test_sink_crypt.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 sink 基类: init_aescfb边界、每条记录独立加密(短iv修复)、等级过滤
//

#include "mx_test.hpp"
#include "sink/sink.hpp"
#include "aes/aes_crypt.hpp"
#include <cstring>

namespace {

/// 暴露protected的cfb128_encrypt，模拟写入端逐条加密
class probe_sink : public mxlogger::sinks::sink {
public:
    int log(const mxlogger::details::log_msg&) override { return 0; }
    void flush() override {}
    std::string encrypt_record(const std::string& plain) {
        std::string out(plain.size(), '\0');
        cfb128_encrypt(plain.data(), &out[0], plain.size());
        return out;
    }
};

/// 模拟解析端: key/iv补零到16字节后对单条密文独立解密
std::string decrypt_standalone(const char* key, const char* iv, const std::string& cipher) {
    uint8_t key16[16] = {}, iv16[16] = {};
    size_t klen = strlen(key);
    memcpy(key16, key, klen > 16 ? 16 : klen);
    size_t ivlen = iv ? strlen(iv) : 0;
    if (ivlen > 0) {
        memcpy(iv16, iv, ivlen > 16 ? 16 : ivlen);
    } else {
        memcpy(iv16, key16, 16);
    }
    mxlogger::aes_crypt c;
    c.set_crypt_key(key16, 16, iv16, 16);
    std::string out(cipher.size(), '\0');
    c.decrypt(cipher.data(), &out[0], cipher.size());
    return out;
}

/// 断言: 写入端连续加密的每条记录，解析端都能独立解出
void check_records_independent(const char* key, const char* iv) {
    probe_sink sink;
    sink.init_aescfb(key, iv);
    const char* msgs[3] = {"first record", "second record longer than one block!", "第三条中文"};
    for (auto* m : msgs) {
        std::string cipher = sink.encrypt_record(m);
        EXPECT_EQ(decrypt_standalone(key, iv, cipher), std::string(m));
    }
}

}

MX_TEST(sink_crypt, no_key_means_no_encrypt) {
    probe_sink s;
    EXPECT_FALSE(s.should_encrypt());
    s.init_aescfb(nullptr, "some_iv");
    EXPECT_FALSE(s.should_encrypt());
}

MX_TEST(sink_crypt, null_iv_no_crash) {
    // 修复前: strlen(nullptr) 直接崩溃
    probe_sink s;
    s.init_aescfb("key12345", nullptr);
    EXPECT_TRUE(s.should_encrypt());
    std::string cipher = s.encrypt_record("works without iv");
    EXPECT_EQ(decrypt_standalone("key12345", nullptr, cipher), std::string("works without iv"));
}

MX_TEST(sink_crypt, short_iv_records_independent) {
    // 核心修复: 短iv下每条记录必须能被解析端独立解密
    // 修复前第2条起向量残留上一条密文，解析端解不出
    check_records_independent("key12345", "iv123");
}

MX_TEST(sink_crypt, full_16_byte_key_iv) {
    check_records_independent("0123456789abcdef", "fedcba9876543210");
}

MX_TEST(sink_crypt, empty_iv_falls_back_to_key) {
    check_records_independent("abcde", "");
}

MX_TEST(sink_crypt, over_long_iv_truncated) {
    // 超过16字节的iv截断使用(修复前会栈溢出)
    check_records_independent("key12345", "0123456789abcdefOVERFLOW");
}

MX_TEST(sink_crypt, level_filter) {
    probe_sink s;
    // 默认debug级别，全部放行
    EXPECT_EQ((int)s.level(), (int)level::debug);
    EXPECT_TRUE(s.should_log(level::debug));
    EXPECT_TRUE(s.should_log(level::fatal));

    // 设为warn后，低于warn的被过滤
    s.set_level(level::warn);
    EXPECT_EQ((int)s.level(), (int)level::warn);
    EXPECT_FALSE(s.should_log(level::debug));
    EXPECT_FALSE(s.should_log(level::info));
    EXPECT_TRUE(s.should_log(level::warn));
    EXPECT_TRUE(s.should_log(level::error));
    EXPECT_TRUE(s.should_log(level::fatal));
}
