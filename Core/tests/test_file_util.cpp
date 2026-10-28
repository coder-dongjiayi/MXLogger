//
//  test_file_util.cpp
//  MXLoggerCore 单元测试
//
//  覆盖 mxlogger_file_util: 路径工具、目录创建、get_files、
//  select_form_path 的边界与损坏文件防护
//

#include "mx_test.hpp"
#include "test_support.hpp"
#include "sink/mmap_sink.hpp"
#include "log_msg.hpp"
#ifdef _WIN32
#include <winioctl.h>
#include <limits>
#endif

using mxtest::record_list;

MX_TEST(file_util, path_exists_and_file_size) {
    std::string dir = mxtest::temp_dir("fu_basic");
    EXPECT_TRUE(mxlogger::path_exists(dir.c_str()));
    EXPECT_FALSE(mxlogger::path_exists((dir + "nope").c_str()));

    mxtest::write_dummy_file(dir + "f.bin", 777);
    EXPECT_TRUE(mxlogger::path_exists((dir + "f.bin").c_str()));
    EXPECT_EQ(mxlogger::file_size((dir + "f.bin").c_str()), (size_t)777);
}

MX_TEST(file_util, create_dir_nested) {
    EXPECT_TRUE(mxtest::reset_dir("mxtest_tmp/fu_nested"));
    // create_dir接收文件路径，逐级创建到最后一个/为止
    EXPECT_TRUE(mxlogger::create_dir("mxtest_tmp/fu_nested/a/b/file.txt"));
    EXPECT_TRUE(mxlogger::path_exists("mxtest_tmp/fu_nested/a/b"));
    // 已存在时幂等
    EXPECT_TRUE(mxlogger::create_dir("mxtest_tmp/fu_nested/a/b/file.txt"));
}

MX_TEST(file_util, get_files_lists_and_skips) {
    std::string dir = mxtest::temp_dir("fu_list");
    mxtest::write_dummy_file(dir + "one.mx", 100);
    mxtest::write_dummy_file(dir + "two.mx", 200);
    mxtest::write_dummy_file(dir + ".DS_Store", 50); // 应被跳过

    record_list files;
    EXPECT_EQ(mxlogger::get_files(&files, dir.c_str()), 0);
    EXPECT_EQ(files.size(), (size_t)2);

    long total = 0;
    for (auto& f : files) {
        EXPECT_TRUE(f["name"] == "one.mx" || f["name"] == "two.mx");
        EXPECT_TRUE(std::stol(f["create_timestamp"]) > 0);
        EXPECT_TRUE(std::stol(f["last_timestamp"]) > 0);
        total += std::stol(f["size"]);
    }
    EXPECT_EQ(total, 300L);

    // 目录不存在返回-1
    record_list none;
    EXPECT_EQ(mxlogger::get_files(&none, "mxtest_tmp/no_such_dir/"), -1);
}

#ifdef _WIN32
MX_TEST(file_util, windows_coordinator_is_reserved_regardless_of_case) {
    const auto dir = mxtest::temp_dir("win_coordinator_case");
    mxtest::write_dummy_file(dir + ".MXLOGGER.LOCK", 0);
    mxlogger::sinks::mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    record_list files;
    EXPECT_EQ(mxlogger::get_files(&files, dir.c_str()), 0);
    EXPECT_EQ(files.size(), size_t(1));
    sink.remove_all();
    files.clear();
    EXPECT_EQ(mxlogger::get_files(&files, dir.c_str()), 0);
    EXPECT_TRUE(files.empty());
    EXPECT_TRUE(mxlogger::path_exists((dir + ".MXLOGGER.LOCK").c_str()));
}

MX_TEST(file_util, windows_absolute_paths_and_separators) {
    const auto root = std::filesystem::absolute(
        std::filesystem::u8path(mxtest::temp_dir("win_paths")));
    // Include a drive prefix, backslashes, spaces and a non-ASCII component.
    const std::string dir = root.u8string() + "\\新目录 空格\\";
    EXPECT_TRUE(mxlogger::create_dir(dir + "file.mx"));
    EXPECT_TRUE(mxlogger::path_exists(dir.c_str()));
    mxtest::write_dummy_file(dir + "中文.mx", 32);
    std::filesystem::create_directory(std::filesystem::u8path(dir + "子目录"));

    record_list files;
    // Listing works even when the caller omits the trailing separator.
    EXPECT_EQ(mxlogger::get_files(&files, dir.substr(0, dir.size() - 1).c_str()), 0);
    EXPECT_EQ(files.size(), (size_t)1);
    if (!files.empty()) EXPECT_EQ(files[0]["name"], std::string("中文.mx"));

    std::string forward = dir;
    std::replace(forward.begin(), forward.end(), '\\', '/');
    EXPECT_TRUE(mxlogger::create_dir(forward + "file.mx"));
    EXPECT_EQ(mxlogger::file_size((forward + "中文.mx").c_str()), (size_t)32);
    EXPECT_EQ(mxlogger::remove_file((forward + "中文.mx").c_str()), 0);
    EXPECT_FALSE(mxlogger::path_exists((dir + "中文.mx").c_str()));

    // Existing drive roots must not be interpreted as directories to create.
    EXPECT_TRUE(mxlogger::create_dir(root.root_path().u8string() + "file.mx"));
}

MX_TEST(file_util, windows_filetime_after_2038) {
    const int64_t unix_seconds = 2208988800LL; // 2040-01-01 UTC
    ULARGE_INTEGER ticks;
    ticks.QuadPart = static_cast<ULONGLONG>(unix_seconds * 10000000LL + 116444736000000000LL);
    FILETIME time{ticks.LowPart, ticks.HighPart};
    EXPECT_EQ(mxlogger::filetime_to_unix(time), unix_seconds);
}

MX_TEST(file_util, windows_large_file_size_and_cleanup) {
    const auto dir = mxtest::temp_dir("win_large");
    mxlogger::sinks::mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    const auto path = dir + "大文件.mx";
    HANDLE file = CreateFileW(mxlogger::utf8_to_wide(path.c_str()).c_str(),
                              GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                              nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    EXPECT_TRUE(file != INVALID_HANDLE_VALUE);
    if (file == INVALID_HANDLE_VALUE) return;

    // Sparse allocation checks >2 GiB accounting without writing gigabytes.
    DWORD returned = 0;
    const bool sparse = DeviceIoControl(file, FSCTL_SET_SPARSE, nullptr, 0,
                                        nullptr, 0, &returned, nullptr) != 0;
    EXPECT_TRUE(sparse);
    LARGE_INTEGER length;
    length.QuadPart = 3LL * 1024 * 1024 * 1024;
    const bool resized = sparse && SetFilePointerEx(file, length, nullptr, FILE_BEGIN) && SetEndOfFile(file);
    EXPECT_TRUE(resized);
    CloseHandle(file);
    if (!resized) return;

    EXPECT_EQ(mxlogger::file_size(path.c_str()), static_cast<size_t>(length.QuadPart));
    EXPECT_EQ(sink.dir_size(), std::numeric_limits<long>::max());
    sink.set_max_disk_size(1);
    sink.remove_expire_data();
    EXPECT_FALSE(mxlogger::path_exists(path.c_str()));
    EXPECT_TRUE(sink.dir_size() > 0); // The current mapped file is preserved.
}
#endif

// 生成一个正常的加密日志文件供损坏测试使用
static std::string make_valid_log(const std::string& dir, int count) {
    mxlogger::sinks::mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
    sink.init_aescfb("key12345", "iv123");
    for (int i = 0; i < count; i++) {
        std::string msg = "record " + std::to_string(i);
        mxlogger::details::log_msg m(level::info, "n", "t", msg.c_str(), false);
        sink.log(m);
    }
    sink.flush();
    return mxtest::first_mx_path(dir);
}

MX_TEST(select_form_path, normal_file) {
    std::string dir = mxtest::temp_dir("sfp_ok");
    std::string path = make_valid_log(dir, 5);

    record_list records;
    EXPECT_EQ(mxlogger::select_form_path(path.c_str(), &records, "key12345", "iv123"), 0);
    EXPECT_EQ(records.size(), (size_t)5);
    if (records.size() == 5) {
        EXPECT_EQ(records[4]["msg"], std::string("record 4"));
    }
}

MX_TEST(select_form_path, empty_key_means_plaintext) {
    // 空key("")与Dart端语义一致: 视为未加密
    std::string dir = mxtest::temp_dir("sfp_plain");
    {
        mxlogger::sinks::mmap_sink sink(dir, "log", policy::yyyy_MM_dd);
        mxlogger::details::log_msg m(level::info, "n", "t", "no crypt", false);
        sink.log(m);
    }
    record_list records;
    EXPECT_EQ(mxlogger::select_form_path(mxtest::first_mx_path(dir).c_str(), &records, "", ""), 0);
    EXPECT_EQ(records.size(), (size_t)1);
    if (!records.empty()) EXPECT_EQ(records[0]["error_code"], std::string("0"));
}

MX_TEST(select_form_path, truncated_file_stops_safely) {
    std::string dir = mxtest::temp_dir("sfp_trunc");
    std::string path = make_valid_log(dir, 5);

    // 磁盘文件按页(4KB)补齐，直接砍一半砍不到数据区，
    // 从头部读出真实数据长度，截断到数据区的一半
    std::string data = mxtest::slurp(path);
    uint32_t total = 0;
    memcpy(&total, data.data(), 4);
    FILE* fp = fopen((dir + "trunc.mx").c_str(), "wb");
    fwrite(data.data(), 1, 4 + total / 2, fp);
    fclose(fp);

    record_list records;
    EXPECT_EQ(mxlogger::select_form_path((dir + "trunc.mx").c_str(), &records, "key12345", "iv123"), 0);
    EXPECT_TRUE(records.size() < 5);
}

MX_TEST(select_form_path, garbage_item_size_stops_safely) {
    std::string dir = mxtest::temp_dir("sfp_garbage");
    // total=100但第一条记录长度是0xFFFFFFFF: 应直接终止而不是malloc 4GB
    FILE* fp = fopen((dir + "bad.mx").c_str(), "wb");
    uint32_t total = 100, bad_size = 0xFFFFFFFF;
    fwrite(&total, 4, 1, fp);
    fwrite(&bad_size, 4, 1, fp);
    fclose(fp);

    record_list records;
    EXPECT_EQ(mxlogger::select_form_path((dir + "bad.mx").c_str(), &records, nullptr, nullptr), 0);
    EXPECT_EQ(records.size(), (size_t)0);

    // 长度为0的记录头同样终止
    fp = fopen((dir + "zero.mx").c_str(), "wb");
    uint32_t zero = 0;
    fwrite(&total, 4, 1, fp);
    fwrite(&zero, 4, 1, fp);
    fclose(fp);
    record_list records2;
    EXPECT_EQ(mxlogger::select_form_path((dir + "zero.mx").c_str(), &records2, nullptr, nullptr), 0);
    EXPECT_EQ(records2.size(), (size_t)0);
}

MX_TEST(select_form_path, empty_and_missing_file) {
    std::string dir = mxtest::temp_dir("sfp_missing");

    // 空文件: 返回-1
    mxtest::write_dummy_file(dir + "empty.mx", 0);
    record_list records;
    EXPECT_EQ(mxlogger::select_form_path((dir + "empty.mx").c_str(), &records, nullptr, nullptr), -1);

    // 不存在的路径: 返回-1，且不能产生副作用文件(修复前O_CREAT会创建)
    std::string ghost = dir + "ghost.mx";
    EXPECT_EQ(mxlogger::select_form_path(ghost.c_str(), &records, nullptr, nullptr), -1);
    EXPECT_FALSE(mxlogger::path_exists(ghost.c_str()));
}
