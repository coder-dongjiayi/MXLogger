//
//  test_mmap_file.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 mmap_sink + base_file_sink: 写入/解析round-trip、持久化、文件头、
//  扩容、等级过滤、文件名策略、目录大小、删除与过期清理
//

#include "mx_test.hpp"
#include "test_support.hpp"
#include "sink/mmap_sink.hpp"
#include "log_msg.hpp"
#include <memory>
#include <unistd.h>

using mxlogger::sinks::mmap_sink;
using mxlogger::details::log_msg;
using mxtest::record_list;

static int write_log(mmap_sink& sink, level::level_enum lvl, const char* msg,
                     const char* name = "test", const char* tag = "tag") {
    log_msg m(lvl, name, tag, msg, false);
    return sink.log(m);
}

MX_TEST(mmap_sink, write_and_parse_roundtrip) {
    std::string dir = mxtest::temp_dir("mmap_roundtrip");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);

    EXPECT_EQ(write_log(sink, level::info, "hello mmap"), 0);
    EXPECT_EQ(write_log(sink, level::error, "中文消息", "myname", "mytag"), 0);
    sink.flush();

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)2);
    if (records.size() == 2) {
        EXPECT_EQ(records[0]["msg"], std::string("hello mmap"));
        EXPECT_EQ(records[0]["level"], std::string("1"));
        EXPECT_EQ(records[0]["name"], std::string("test"));
        EXPECT_EQ(records[0]["tag"], std::string("tag"));
        EXPECT_EQ(records[0]["is_main_thread"], std::string("0"));
        EXPECT_TRUE(std::stoll(records[0]["timestamp"]) > 0);
        EXPECT_TRUE(std::stol(records[0]["thread_id"]) != 0);
        EXPECT_EQ(records[1]["msg"], std::string("中文消息"));
        EXPECT_EQ(records[1]["level"], std::string("3"));
    }
}

MX_TEST(mmap_sink, persistence_across_reopen) {
    std::string dir = mxtest::temp_dir("mmap_persist");
    {
        mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
        write_log(sink, level::info, "before close");
    } // 析构: munmap + close

    {
        mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
        write_log(sink, level::info, "after reopen");
    }

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)2);
    if (records.size() == 2) {
        EXPECT_EQ(records[0]["msg"], std::string("before close"));
        EXPECT_EQ(records[1]["msg"], std::string("after reopen"));
    }
}

MX_TEST(mmap_sink, file_header_written_once) {
    std::string dir = mxtest::temp_dir("mmap_header");
    {
        mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
        sink.add_file_heder("device: iPhone; os: 17.0");
        write_log(sink, level::info, "normal log");
    }
    {
        // 文件非空时重复添加header应被忽略
        mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
        sink.add_file_heder("second header should be ignored");
        write_log(sink, level::info, "another log");
    }

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)3);
    int header_count = 0;
    for (auto& r : records) {
        if (r["name"] == "com.djy.mxlogger.fileHeader") header_count++;
    }
    EXPECT_EQ(header_count, 1);
    if (!records.empty()) {
        EXPECT_EQ(records[0]["name"], std::string("com.djy.mxlogger.fileHeader"));
        EXPECT_EQ(records[0]["msg"], std::string("device: iPhone; os: 17.0"));
    }
    // header为nullptr时不写入
    std::string dir2 = mxtest::temp_dir("mmap_no_header");
    mmap_sink sink2(dir2, "log", policy::yyyy_MM_dd);
    sink2.add_file_heder(nullptr);
    write_log(sink2, level::info, "only");
    EXPECT_EQ(mxtest::parse_dir(dir2).size(), (size_t)1);
}

MX_TEST(mmap_sink, grows_beyond_page_size) {
    // 写入量远超一页(4096)，触发多次truncate扩容后数据完整
    std::string dir = mxtest::temp_dir("mmap_grow");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);

    std::string payload(200, 'P');
    const int count = 300;
    for (int i = 0; i < count; i++) {
        std::string msg = std::to_string(i) + ":" + payload;
        EXPECT_EQ(write_log(sink, level::info, msg.c_str()), 0);
    }
    sink.flush();

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)count);
    if (records.size() == (size_t)count) {
        EXPECT_EQ(records[0]["msg"].substr(0, 2), std::string("0:"));
        EXPECT_EQ(records[count - 1]["msg"].substr(0, 4), std::string("299:"));
    }
}

MX_TEST(mmap_sink, level_filter_skips_write) {
    std::string dir = mxtest::temp_dir("mmap_level");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    sink.set_level(level::error);

    EXPECT_EQ(write_log(sink, level::debug, "filtered"), 0);
    EXPECT_EQ(write_log(sink, level::warn, "filtered too"), 0);
    EXPECT_EQ(write_log(sink, level::error, "written"), 0);
    EXPECT_EQ(write_log(sink, level::fatal, "written too"), 0);

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)2);
    if (records.size() == 2) {
        EXPECT_EQ(records[0]["msg"], std::string("written"));
    }
}

MX_TEST(mmap_sink, encryption_hides_plaintext) {
    // 不加密: 文件内可找到明文; 加密: 找不到明文
    std::string plain_dir = mxtest::temp_dir("mmap_plain");
    {
        mmap_sink sink(plain_dir, "log", policy::yyyy_MM_dd);
        write_log(sink, level::info, "FINDME_SECRET_TOKEN");
    }
    EXPECT_TRUE(mxtest::contains_bytes(mxtest::slurp(mxtest::first_mx_path(plain_dir)),
                                       "FINDME_SECRET_TOKEN"));

    std::string crypt_dir = mxtest::temp_dir("mmap_crypt");
    {
        mmap_sink sink(crypt_dir, "log", policy::yyyy_MM_dd);
        sink.init_aescfb("key12345", "iv123");
        write_log(sink, level::info, "FINDME_SECRET_TOKEN");
    }
    EXPECT_FALSE(mxtest::contains_bytes(mxtest::slurp(mxtest::first_mx_path(crypt_dir)),
                                        "FINDME_SECRET_TOKEN"));
    // 但用正确的key/iv能解出
    record_list records = mxtest::parse_dir(crypt_dir, "key12345", "iv123");
    EXPECT_EQ(records.size(), (size_t)1);
    if (!records.empty()) {
        EXPECT_EQ(records[0]["msg"], std::string("FINDME_SECRET_TOKEN"));
        EXPECT_EQ(records[0]["error_code"], std::string("0"));
    }
}

MX_TEST(mmap_sink, recovers_after_initial_open_failure) {
    // 构造/映射失败必须是瞬时的: 障碍解除后同一个sink实例在下一次写入时自愈,
    // 而不是从此永久返回错误(回归: 映射失败分支曾close掉fd导致永久失能)
    std::string root = mxtest::temp_dir("mmap_recover");
    std::string blocker = root + "blocker";
    mxtest::write_dummy_file(blocker, 1);

    // 父路径被普通文件占住 → create_dir/open全部失败, fd=-1, 无映射
    std::string dir = blocker + "/sub/";
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);

    // 初始不可写: 写入返回-3(映射失败), 不崩溃
    EXPECT_EQ(write_log(sink, level::info, "before-recover"), -3);

    // 障碍解除后, 无需重建sink, 下一次写入自动重开文件+重建映射
    ::remove(blocker.c_str());
    EXPECT_TRUE(mxlogger::create_dir(dir));
    EXPECT_EQ(write_log(sink, level::info, "after-recover"), 0);
    sink.flush();

    record_list records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), (size_t)1);
    if (!records.empty()) {
        EXPECT_EQ(records[0]["msg"], std::string("after-recover"));
    }
}

MX_TEST(file_sink, filename_policies) {
    std::tm t = mxlogger_helper::now();
    char ym[16], ymd[16], ymdh[20];
    snprintf(ym, sizeof(ym), "%04d-%02d", t.tm_year + 1900, t.tm_mon + 1);
    snprintf(ymd, sizeof(ymd), "%04d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
    snprintf(ymdh, sizeof(ymdh), "%04d-%02d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour);

    struct { policy::storage_policy p; std::string expect; } cases[] = {
        {policy::yyyy_MM,       std::string(ym) + "_mylog.mx"},
        {policy::yyyy_MM_dd,    std::string(ymd) + "_mylog.mx"},
        {policy::yyyy_MM_dd_HH, std::string(ymdh) + "_mylog.mx"},
    };
    for (auto& c : cases) {
        std::string dir = mxtest::temp_dir("policy_" + std::to_string((int)c.p));
        mmap_sink sink(dir, "mylog", c.p);
        write_log(sink, level::info, "x");
        record_list files;
        mxlogger::get_files(&files, dir.c_str());
        EXPECT_EQ(files.size(), (size_t)1);
        if (!files.empty()) EXPECT_EQ(files[0]["name"], c.expect);
    }

    // 周策略格式: YYYY-MM-NNw_mylog.mx，周数1~53
    std::string wdir = mxtest::temp_dir("policy_week");
    mmap_sink wsink(wdir, "mylog", policy::yyyy_ww);
    write_log(wsink, level::info, "x");
    record_list wfiles;
    mxlogger::get_files(&wfiles, wdir.c_str());
    EXPECT_EQ(wfiles.size(), (size_t)1);
    if (!wfiles.empty()) {
        std::string name = wfiles[0]["name"];
        EXPECT_TRUE(name.find("w_mylog.mx") != std::string::npos);
        EXPECT_EQ(name.substr(0, 8), std::string(ym) + "-");
    }
}

MX_TEST(file_sink, dir_size_matches_files) {
    std::string dir = mxtest::temp_dir("dir_size");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    write_log(sink, level::info, "some content");
    sink.flush();

    long size = sink.dir_size();
    EXPECT_TRUE(size > 0);
    // 与get_files统计一致
    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    long sum = 0;
    for (auto& f : files) sum += std::stol(f["size"]);
    EXPECT_EQ(size, sum);
}

MX_TEST(file_sink, remove_before_all_keeps_current) {
    std::string dir = mxtest::temp_dir("remove_before");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    write_log(sink, level::info, "current");
    mxtest::write_dummy_file(dir + "old1.mx", 128);
    mxtest::write_dummy_file(dir + "old2.mx", 128);

    sink.remove_before_all();

    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    EXPECT_EQ(files.size(), (size_t)1);
    if (!files.empty()) {
        EXPECT_EQ(files[0]["name"], mxtest::today_prefix() + "_log.mx");
    }
}

MX_TEST(file_sink, remove_all_clears_dir) {
    std::string dir = mxtest::temp_dir("remove_all");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    write_log(sink, level::info, "x");
    mxtest::write_dummy_file(dir + "old.mx", 128);

    sink.remove_all();

    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    EXPECT_EQ(files.size(), (size_t)0);
}

MX_TEST(file_sink, expire_by_max_age) {
    std::string dir = mxtest::temp_dir("expire_age");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    write_log(sink, level::info, "current");

    mxtest::write_dummy_file(dir + "ancient.mx", 128);
    mxtest::set_mtime_days_ago(dir + "ancient.mx", 10);
    mxtest::write_dummy_file(dir + "fresh.mx", 128);

    sink.set_max_disk_age(86400); // 1天
    sink.remove_expire_data();

    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    bool has_ancient = false, has_fresh = false, has_current = false;
    for (auto& f : files) {
        if (f["name"] == "ancient.mx") has_ancient = true;
        if (f["name"] == "fresh.mx") has_fresh = true;
        if (f["name"] == mxtest::today_prefix() + "_log.mx") has_current = true;
    }
    EXPECT_FALSE(has_ancient);
    EXPECT_TRUE(has_fresh);
    EXPECT_TRUE(has_current);
}

MX_TEST(file_sink, expire_by_max_size_only_oldest_first) {
    // 覆盖两个修复: 只设max_size(不设max_age)清理必须生效; 且先删最旧的文件
    std::string dir = mxtest::temp_dir("expire_size");
    mmap_sink sink(dir, "log", policy::yyyy_MM_dd);

    // 创建间隔>1s保证birthtime可区分(秒级精度)
    mxtest::write_dummy_file(dir + "a_oldest.mx", 4096);
    sleep(2);
    mxtest::write_dummy_file(dir + "b_middle.mx", 4096);
    sleep(2);
    mxtest::write_dummy_file(dir + "c_newest.mx", 4096);

    // 当前正在写入的mmap文件占4KB(一页)，总量 = 4+12 = 16KB
    // 上限10KB: 应删a(→12KB)、删b(→8KB达标)，留c和当前文件
    sink.set_max_disk_size(10 * 1024);
    sink.remove_expire_data();

    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    bool has_a = false, has_b = false, has_c = false;
    for (auto& f : files) {
        if (f["name"] == "a_oldest.mx") has_a = true;
        if (f["name"] == "b_middle.mx") has_b = true;
        if (f["name"] == "c_newest.mx") has_c = true;
    }
    EXPECT_FALSE(has_a);
    EXPECT_FALSE(has_b);
    EXPECT_TRUE(has_c);
}
