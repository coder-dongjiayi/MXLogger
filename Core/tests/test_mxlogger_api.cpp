//
//  test_mxlogger_api.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 mxlogger 门面: 多例注册表、logger_key/md5、日志写入默认值、
//  开关与等级、加密链路、释放接口、空参数安全
//

#include "mx_test.hpp"
#include "test_support.hpp"
#include "mxlogger.hpp"

using mxtest::record_list;

static const char* API_DIR = "mxtest_tmp/api";

MX_TEST(mxlogger_api, singleton_registry_and_keys) {
    auto* a = mx_logger::initialize_namespace("ns1", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    EXPECT_TRUE(a != nullptr);

    // 同ns+目录返回同一实例
    auto* a2 = mx_logger::initialize_namespace("ns1", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    EXPECT_TRUE(a == a2);

    // 不同ns是不同实例
    auto* b = mx_logger::initialize_namespace("ns2", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    EXPECT_TRUE(b != nullptr && b != a);

    // logger_key == md5(目录+ns)，32位十六进制
    std::string key = a->logger_key();
    EXPECT_EQ(key.size(), (size_t)32);
    EXPECT_EQ(key, mx_logger::md5("ns1", API_DIR));

    // 通过key能取回实例；未知key/空key返回null
    EXPECT_TRUE(mx_logger::global_for_loggerKey(key.c_str()) == a);
    EXPECT_TRUE(mx_logger::global_for_loggerKey("no_such_key") == nullptr);
    EXPECT_TRUE(mx_logger::global_for_loggerKey(nullptr) == nullptr);

    // diskcache_path = 目录/ns/
    EXPECT_TRUE(std::string(a->diskcache_path()).find("/ns1/") != std::string::npos);

    // ns为null时使用"default"
    auto* d = mx_logger::initialize_namespace(nullptr, API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    EXPECT_TRUE(d != nullptr);
    EXPECT_EQ(std::string(d->logger_key()), mx_logger::md5("default", API_DIR));

    mx_logger::destroy();
}

MX_TEST(mxlogger_api, log_defaults_and_field_mapping) {
    auto* logger = mx_logger::initialize_namespace("fields", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);

    // name为null默认"mxlogger"; tag可null; 主线程标记
    EXPECT_EQ(logger->log(1, nullptr, "message one", nullptr, true), 0);
    // 越界level回退debug(0)
    EXPECT_EQ(logger->log(99, "myname", "message two", "mytag", false), 0);
    logger->flush();

    record_list records = mxtest::parse_dir(std::string(logger->diskcache_path()));
    EXPECT_EQ(records.size(), (size_t)2);
    if (records.size() == 2) {
        EXPECT_EQ(records[0]["name"], std::string("mxlogger"));
        EXPECT_EQ(records[0]["tag"], std::string(""));
        EXPECT_EQ(records[0]["is_main_thread"], std::string("1"));
        EXPECT_EQ(records[0]["level"], std::string("1"));
        EXPECT_EQ(records[1]["name"], std::string("myname"));
        EXPECT_EQ(records[1]["level"], std::string("0"));
    }
    EXPECT_EQ(std::string(logger->error_desc()), std::string(""));

    mx_logger::delete_namespace("fields", API_DIR);
}

MX_TEST(mxlogger_api, enable_flag_and_log_level) {
    auto* logger = mx_logger::initialize_namespace("enable", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    std::string dir = logger->diskcache_path();

    logger->set_enable(false);
    EXPECT_EQ(logger->log(1, "n", "not written", "t", false), 0);
    EXPECT_EQ(mxtest::parse_dir(dir).size(), (size_t)0);

    logger->set_enable(true);
    logger->log(1, "n", "written", "t", false);
    EXPECT_EQ(mxtest::parse_dir(dir).size(), (size_t)1);

    // 存储等级过滤
    logger->set_log_level(3); // error
    logger->log(0, "n", "debug filtered", "t", false);
    logger->log(3, "n", "error written", "t", false);
    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)2);
    if (records.size() == 2) {
        EXPECT_EQ(records[1]["msg"], std::string("error written"));
    }

    mx_logger::delete_namespace("enable", API_DIR);
}

MX_TEST(mxlogger_api, crypt_full_chain) {
    // 短key+短iv走完整链路: 初始化(带文件头) -> 写入 -> 解析
    auto* logger = mx_logger::initialize_namespace("crypt", API_DIR, nullptr, nullptr,
                                                   "header info", "key12345", "iv123");
    std::string dir = logger->diskcache_path();
    logger->log(1, "n", "encrypted message 中文", "t", false);
    logger->log(2, "n", "second message", "t", false);
    logger->flush();

    // 明文不可见
    EXPECT_FALSE(mxtest::contains_bytes(mxtest::slurp(mxtest::first_mx_path(dir)),
                                        "encrypted message"));

    // 正确key/iv: 文件头 + 2条记录全部解出
    record_list good = mxtest::parse_dir(dir, "key12345", "iv123");
    EXPECT_EQ(good.size(), (size_t)3);
    if (good.size() == 3) {
        EXPECT_EQ(good[0]["name"], std::string("com.djy.mxlogger.fileHeader"));
        EXPECT_EQ(good[0]["msg"], std::string("header info"));
        EXPECT_EQ(good[1]["msg"], std::string("encrypted message 中文"));
        EXPECT_EQ(good[1]["error_code"], std::string("0"));
    }

    // 错误key: 记录标记为数据异常error_code=1
    record_list bad = mxtest::parse_dir(dir, "wrong_key", "iv123");
    EXPECT_EQ(bad.size(), (size_t)3);
    for (auto& r : bad) {
        EXPECT_EQ(r["error_code"], std::string("1"));
    }

    mx_logger::delete_namespace("crypt", API_DIR);
}

MX_TEST(mxlogger_api, console_output_no_crash) {
    // 控制台输出路径(含cJSON解析/释放): 普通消息 + JSON消息
    auto* logger = mx_logger::initialize_namespace("console", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    logger->set_enable_console(true);
    EXPECT_EQ(logger->log(1, "n", "plain console message", "t", true), 0);
    EXPECT_EQ(logger->log(2, "n", "{\"key\":\"value\",\"num\":42}", "t", false), 0);
    logger->set_enable_console(false);
    EXPECT_EQ(mxtest::parse_dir(std::string(logger->diskcache_path())).size(), (size_t)2);
    mx_logger::delete_namespace("console", API_DIR);
}

MX_TEST(mxlogger_api, remove_and_dir_size) {
    auto* logger = mx_logger::initialize_namespace("remove", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    logger->log(1, "n", "content", "t", false);
    logger->flush();
    EXPECT_TRUE(logger->dir_size() > 0);

    logger->set_file_max_size(1);
    logger->set_file_max_age(86400);
    logger->remove_expire_data(); // 当前文件不删
    EXPECT_TRUE(logger->dir_size() > 0);

    logger->remove_before_all();
    EXPECT_TRUE(logger->dir_size() > 0); // 当前文件保留

    logger->remove_all();
    EXPECT_EQ(logger->dir_size(), 0L);

    mx_logger::delete_namespace("remove", API_DIR);
}

MX_TEST(mxlogger_api, delete_and_destroy) {
    auto* a = mx_logger::initialize_namespace("del_a", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    std::string key_a = a->logger_key();

    // 按ns+目录删除
    mx_logger::delete_namespace("del_a", API_DIR);
    EXPECT_TRUE(mx_logger::global_for_loggerKey(key_a.c_str()) == nullptr);

    // 按logger_key删除
    auto* b = mx_logger::initialize_namespace("del_b", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    std::string key_b = b->logger_key();
    mx_logger::delete_namespace(key_b.c_str());
    EXPECT_TRUE(mx_logger::global_for_loggerKey(key_b.c_str()) == nullptr);

    // destroy清空全部
    auto* c = mx_logger::initialize_namespace("del_c", API_DIR, nullptr, nullptr, nullptr, nullptr, nullptr);
    std::string key_c = c->logger_key();
    mx_logger::destroy();
    EXPECT_TRUE(mx_logger::global_for_loggerKey(key_c.c_str()) == nullptr);

    // 空参数安全: 不崩溃
    mx_logger::delete_namespace("ns", nullptr);
    mx_logger::delete_namespace("never_registered_key_1234567890ab");
    mx_logger::destroy(); // 空表destroy
    EXPECT_TRUE(true);
}
