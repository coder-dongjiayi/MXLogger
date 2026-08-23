//
//  test_helper.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 mxlogger_helper: 等级/策略映射、md5、格式化、时间函数
//  以及 debug_log、logger_os
//

#include "mx_test.hpp"
#include "mxlogger_helper.hpp"
#include "debug_log.hpp"
#include "logger_os.hpp"
#include <thread>

MX_TEST(helper, level_mapping) {
    EXPECT_EQ((int)mxlogger_helper::level_(0), (int)level::debug);
    EXPECT_EQ((int)mxlogger_helper::level_(1), (int)level::info);
    EXPECT_EQ((int)mxlogger_helper::level_(2), (int)level::warn);
    EXPECT_EQ((int)mxlogger_helper::level_(3), (int)level::error);
    EXPECT_EQ((int)mxlogger_helper::level_(4), (int)level::fatal);
    // 越界回退debug
    EXPECT_EQ((int)mxlogger_helper::level_(99), (int)level::debug);
    EXPECT_EQ((int)mxlogger_helper::level_(-1), (int)level::debug);
}

MX_TEST(helper, policy_mapping) {
    EXPECT_EQ((int)mxlogger_helper::policy_(nullptr), (int)policy::yyyy_MM_dd);
    EXPECT_EQ((int)mxlogger_helper::policy_("yyyy_MM"), (int)policy::yyyy_MM);
    EXPECT_EQ((int)mxlogger_helper::policy_("yyyy_MM_dd"), (int)policy::yyyy_MM_dd);
    EXPECT_EQ((int)mxlogger_helper::policy_("yyyy_ww"), (int)policy::yyyy_ww);
    EXPECT_EQ((int)mxlogger_helper::policy_("yyyy_MM_dd_HH"), (int)policy::yyyy_MM_dd_HH);
    // 未知字符串回退默认
    EXPECT_EQ((int)mxlogger_helper::policy_("bogus"), (int)policy::yyyy_MM_dd);
}

MX_TEST(helper, md5_stable_hex_key) {
    // 注意: md5.h 中 UINT4 被定义为 unsigned long(64位平台上是8字节)，
    // 所以64位平台产出的并非RFC 1321标准MD5值，而是一个内部自洽的稳定哈希。
    // logger_key 只依赖"稳定+唯一"，这里断言库实际提供的保证；
    // 若未来改为标准MD5，会改变所有 logger_key 的取值，需评估兼容性。

    // 输出恒为32个十六进制字符
    std::string h = mxlogger_helper::mx_md5(std::string("abc"));
    EXPECT_EQ(h.size(), (size_t)32);
    EXPECT_TRUE(h.find_first_not_of("0123456789abcdef") == std::string::npos);
    EXPECT_EQ(mxlogger_helper::mx_md5(std::string("任意中文输入")).size(), (size_t)32);

    // 相同输入结果稳定，不同输入结果不同
    EXPECT_EQ(mxlogger_helper::mx_md5(std::string("stable")),
              mxlogger_helper::mx_md5(std::string("stable")));
    EXPECT_TRUE(mxlogger_helper::mx_md5(std::string("a")) !=
                mxlogger_helper::mx_md5(std::string("b")));
}

MX_TEST(helper, string_format) {
    EXPECT_EQ(mxlogger_helper::string_format("%d-%s", 42, "x"), std::string("42-x"));
    EXPECT_EQ(mxlogger_helper::string_format("%04d", 7), std::string("0007"));
    EXPECT_EQ(mxlogger_helper::string_format("no args"), std::string("no args"));
}

MX_TEST(helper, time_functions) {
    auto now = std::chrono::system_clock::now();

    // 微秒时间戳与系统时间一致(1秒容差)
    int64_t ts = mxlogger_helper::time_stamp_microseconds(now);
    int64_t sys_us = (int64_t)time(nullptr) * 1000000;
    EXPECT_TRUE(ts > sys_us - 1000000 && ts < sys_us + 2000000);

    // "YYYY-MM-DD HH:MM:SS.ffffff" 固定26字符
    std::string dt = mxlogger_helper::micros_datetime(now);
    EXPECT_EQ(dt.size(), (size_t)26);
    EXPECT_EQ(dt[4], '-');
    EXPECT_EQ(dt[7], '-');
    EXPECT_EQ(dt[10], ' ');
    EXPECT_EQ(dt[13], ':');
    EXPECT_EQ(dt[19], '.');

    // "HH:MM:SS.ffffff" 固定15字符
    std::string t = mxlogger_helper::micros_time(now);
    EXPECT_EQ(t.size(), (size_t)15);
    EXPECT_EQ(t[2], ':');
    EXPECT_EQ(t[8], '.');
}

MX_TEST(debug_log, short_and_long_message) {
    // 返回值格式: [级别][文件:行 函数] 消息，出错位置会一并带给 errorDesc
    // 短消息(小于内部栈缓冲)
    std::string s = _debug_log(0, "f.cpp", "fn", 1, "%s", "hi");
    EXPECT_EQ(s, std::string("[mxlogger_info][f.cpp:1 fn] hi"));

    // 长消息走resize路径，内容不能截断
    std::string long_msg(100, 'A');
    std::string l = _debug_log(1, "f.cpp", "fn", 1, "%s", long_msg.c_str());
    EXPECT_EQ(l, std::string("[mxlogger_error][f.cpp:1 fn] ") + long_msg);

    // filename/func 为空指针时不能崩，降级成 "?"
    std::string n = _debug_log(1, nullptr, nullptr, 7, "%s", "x");
    EXPECT_EQ(n, std::string("[mxlogger_error][?:7 ?] x"));
}

MX_TEST(logger_os, thread_id) {
    size_t id1 = mxlogger::details::logger_os::thread_id();
    size_t id2 = mxlogger::details::logger_os::thread_id();
    // 同线程内稳定且非0
    EXPECT_TRUE(id1 != 0);
    EXPECT_EQ(id1, id2);

    // 不同线程id不同
    size_t other = 0;
    std::thread t([&other]() { other = mxlogger::details::logger_os::thread_id(); });
    t.join();
    EXPECT_TRUE(other != 0);
    EXPECT_TRUE(other != id1);
}
