#include "mxlogger_interprocess.hpp"
#if MXLOGGER_MULTIPROCESS
#include "test_support.hpp"
#include "sink/mmap_sink.hpp"
#include "log_msg.hpp"
#include "test_process.hpp"
#include <set>

using mxlogger::sinks::mmap_sink;
using mxlogger::details::log_msg;
using mxtest::record_list;
using mxtest::worker;
static const char *crypt_key = "ipc-key-12345678";
static const char *crypt_iv = "short-iv";

int mxlogger_process_worker(int argc, char **argv) {
    if (argc != 9) return 20;
    const std::string dir = argv[2];
    const int id = atoi(argv[4]), count = atoi(argv[5]);
    const bool crypt = atoi(argv[6]) != 0;
    const auto control = mxtest::parse_pipe(argv[7]), report = mxtest::parse_pipe(argv[8]);
    {
        mmap_sink sink(dir, argv[3], policy::yyyy_MM_dd);
#ifdef _WIN32
        mxlogger::files::native_file external_file;
        mxlogger::files::mapped_view external_view;
#endif
        if (crypt) sink.init_aescfb(crypt_key, crypt_iv);
        if (!sink.error_record.empty()) return 21;
        if (!mxtest::write_byte(report, 'R')) return 22;
        int round = 0;
        char command;
        while (mxtest::read_byte(control, command)) {
            if (command == 'Q') break;
            if (command == 'H') {
                sink.add_file_heder("shared header");
            } else if (command == 'W' || command == 'V') {
                if (command == 'V') {
                    mxlogger::files::native_file probe;
                    if (!probe.open(mxlogger::ipc::coordination_path(dir)) || probe.lock(true, false)) return 32;
                    if (!mxtest::write_byte(report, 'B')) return 33;
                }
                for (int i = 0; i < count; ++i) {
                    std::string msg = std::to_string(id) + ":" + std::to_string(round) + ":" + std::to_string(i) + ":" + std::string(512, 'P');
                    log_msg record(level::info, "ipc", "tag", msg.c_str(), false);
                    if (sink.log(record) != 0) return 23;
                }
                ++round;
            }
#ifdef _WIN32
            else if (command == 'M') {
                // Deliberately retain a foreign view outside the protocol to
                // exercise native resize failure and recovery in another process.
                const auto path = mxtest::first_mx_path(dir);
                mxlogger::files::file_info info;
                if (!external_file.open(path, true) || !external_file.info(info) ||
                    !external_view.map(external_file, static_cast<size_t>(info.size), false)) return 30;
            } else if (command == 'U') {
                if (!external_view.unmap() || !external_file.close()) return 31;
            }
#endif
            else if (command == 'T') {
                mxlogger::ipc::directory_lock directory_lock(dir);
                mxlogger::ipc::scoped_lock lock(directory_lock);
                if (!lock) return 24;
                std::string path = mxtest::first_mx_path(dir);
                mxlogger::files::native_file file;
                uint32_t committed = 0;
                if (!file.open(path) || file.read_at(&committed, 4, 0) != 4 ||
                    file.write_at("uncommitted-tail", 16, 4 + committed) != 16) return 25;
                file.close();
                if (!mxtest::write_byte(report, 'L')) return 26;
                // Terminate while the OS directory lock and live-file lease are held.
                mxtest::wait_forever();
            } else return 27;
            if (!mxtest::write_byte(report, 'D')) return 28;
        }
    } // Release the data-file lease before acknowledging a graceful exit.
    return mxtest::write_byte(report, 'Q') ? 0 : 29;
}

static void check_records(const record_list &records, size_t count, bool header = false, int round = -1) {
    EXPECT_EQ(records.size(), count + (header ? 1 : 0));
    std::set<std::string> messages;
    int headers = 0;
    for (const auto &record : records) {
        auto get = [&](const char *key) { auto it = record.find(key); return it == record.end() ? std::string() : it->second; };
        EXPECT_EQ(get("error_code"), std::string("0"));
        if (get("name") == "com.djy.mxlogger.fileHeader") { ++headers; continue; }
        EXPECT_EQ(get("name"), std::string("ipc"));
        std::string msg = get("msg");
        EXPECT_TRUE(msg.size() > 512 && msg.substr(msg.size() - 512) == std::string(512, 'P'));
        if (round >= 0) {
            auto start = msg.find(':');
            EXPECT_TRUE(start != std::string::npos && msg.substr(start + 1, 1) == std::to_string(round));
        }
        messages.insert(msg);
    }
    EXPECT_EQ(messages.size(), count);
    EXPECT_EQ(headers, header ? 1 : 0);
}

MX_TEST(multiprocess, stale_offset_and_capacity_are_refreshed) {
    std::string dir = mxtest::temp_dir("ipc_stale");
    worker a(dir, 1), b(dir, 2);
    EXPECT_TRUE(a.receive('R')); EXPECT_TRUE(b.receive('R'));
    EXPECT_TRUE(a.send('W')); EXPECT_TRUE(a.receive());
    // B initialized before A expanded; it must refresh capacity and append offset.
    EXPECT_TRUE(b.send('W')); EXPECT_TRUE(b.receive());
    check_records(mxtest::parse_dir(dir), 300);
    EXPECT_TRUE(a.finish()); EXPECT_TRUE(b.finish());
}

MX_TEST(multiprocess, shared_snapshot_blocks_writer_until_view_is_released) {
    const auto dir = mxtest::temp_dir("ipc_snapshot_barrier");
    worker writer(dir, 1, 40);
    EXPECT_TRUE(writer.receive('R'));
    {
        mxlogger::ipc::directory_lock coordinator(dir);
        mxlogger::ipc::scoped_lock snapshot_lock(coordinator, false);
        EXPECT_TRUE(bool(snapshot_lock));
        mxlogger::files::native_file file;
        mxlogger::files::file_info info;
        mxlogger::files::mapped_view view;
        EXPECT_TRUE(file.open(mxtest::first_mx_path(dir), true));
        EXPECT_TRUE(file.info(info));
        EXPECT_TRUE(view.map(file, static_cast<size_t>(info.size), false));
        EXPECT_TRUE(writer.send('V'));
        EXPECT_TRUE(writer.receive('B')); // The child observed the conflicting shared lock.
        EXPECT_FALSE(writer.pending(100));
    } // View, file and then shared lock: growth may now proceed.
    EXPECT_TRUE(writer.receive());
    check_records(mxtest::parse_dir(dir), 40);
    EXPECT_TRUE(writer.finish());
}

MX_TEST(multiprocess, unicode_directory_and_worker_arguments) {
    std::string dir = mxtest::temp_dir("多进程 空格/日志");
#ifdef _WIN32
    dir = std::filesystem::absolute(std::filesystem::u8path(dir)).u8string();
    if (dir.back() != '\\') dir += '\\';
#endif
    worker a(dir, 1, 20, true, "共享日志"), b(dir, 2, 20, true, "共享日志");
    EXPECT_TRUE(a.receive('R')); EXPECT_TRUE(b.receive('R'));
    EXPECT_TRUE(a.send('W')); EXPECT_TRUE(b.send('W'));
    EXPECT_TRUE(a.receive()); EXPECT_TRUE(b.receive());
    check_records(mxtest::parse_dir(dir, crypt_key, crypt_iv), 40);
    EXPECT_TRUE(a.finish()); EXPECT_TRUE(b.finish());
}

#ifdef _WIN32
MX_TEST(multiprocess, foreign_windows_mapping_growth_and_recovery) {
    const auto dir = mxtest::temp_dir("ipc_foreign_mapping");
    worker foreign(dir, 1, 1);
    EXPECT_TRUE(foreign.receive('R'));
    mmap_sink writer(dir, "shared", policy::yyyy_MM_dd);
    log_msg first(level::info, "foreign", nullptr, "before growth", false);
    EXPECT_EQ(writer.log(first), 0);
    EXPECT_TRUE(foreign.send('M')); EXPECT_TRUE(foreign.receive());

    std::string payload(128 * 1024, 'X');
    log_msg growth(level::info, "foreign", nullptr, payload.c_str(), false);
    int result = writer.log(growth);
    EXPECT_TRUE(result == 0 || result == -1 || result == -3);
    if (result != 0) EXPECT_FALSE(writer.error_record.empty());
    printf("  Windows foreign-view extension result: %d\n", result);
    EXPECT_TRUE(foreign.send('U')); EXPECT_TRUE(foreign.receive());
    EXPECT_EQ(writer.log(growth), 0);
    auto records = mxtest::parse_dir(dir);
    EXPECT_EQ(records.size(), size_t(result == 0 ? 3 : 2));
    if (!records.empty()) EXPECT_EQ(records.front()["msg"], std::string("before growth"));
    if (records.size() >= 2) EXPECT_EQ(records.back()["msg"], payload);
    EXPECT_TRUE(foreign.finish());
}
#endif

static void concurrent_append(bool crypt) {
    std::string root = mxtest::temp_dir(crypt ? "ipc_parallel_crypt" : "ipc_parallel");
    std::string dir = root + "new/nested/";
    worker a(dir, 1, 150, crypt), b(dir, 2, 150, crypt), c(dir, 3, 150, crypt), d(dir, 4, 150, crypt);
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->receive('R'));
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->send('H'));
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->receive());
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->send('W'));
    size_t previous = 0;
    for (int i = 0; i < 12; ++i) {
        auto records = mxtest::parse_dir(dir, crypt ? crypt_key : nullptr, crypt ? crypt_iv : nullptr);
        EXPECT_TRUE(records.size() >= previous && records.size() <= 601);
        for (auto &record : records) EXPECT_EQ(record["error_code"], std::string("0"));
        previous = records.size();
    }
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->receive());
    check_records(mxtest::parse_dir(dir, crypt ? crypt_key : nullptr, crypt ? crypt_iv : nullptr), 600, true);
    for (auto *p : {&a, &b, &c, &d}) EXPECT_TRUE(p->finish());
}
MX_TEST(multiprocess, concurrent_append_header_and_read_snapshots) { concurrent_append(false); }
MX_TEST(multiprocess, concurrent_encrypted_append_and_read_snapshots) { concurrent_append(true); }

MX_TEST(multiprocess, cleanup_preserves_other_process_live_files) {
    std::string dir = mxtest::temp_dir("ipc_cleanup");
    worker other(dir, 1, 1, false, "other");
    EXPECT_TRUE(other.receive('R'));
    EXPECT_TRUE(other.send('W')); EXPECT_TRUE(other.receive());
    std::string active = mxtest::first_mx_path(dir);
    mxtest::set_mtime_days_ago(active, 10);
    mmap_sink cleaner(dir, "cleaner", policy::yyyy_MM_dd);
    cleaner.set_max_disk_age(86400);
    cleaner.set_max_disk_size(1);
    cleaner.remove_expire_data();
    EXPECT_TRUE(mxlogger::path_exists(active.c_str()));
    cleaner.remove_before_all();
    EXPECT_TRUE(mxlogger::path_exists(active.c_str()));
    EXPECT_TRUE(other.finish());
    cleaner.remove_expire_data();
    EXPECT_FALSE(mxlogger::path_exists(active.c_str()));
    EXPECT_TRUE(mxlogger::path_exists((dir + mxlogger::ipc::lock_filename).c_str()));
}

MX_TEST(multiprocess, remove_all_reopens_live_mappings_in_every_process) {
    std::string dir = mxtest::temp_dir("ipc_remove_all");
    worker a(dir, 1), b(dir, 2);
    EXPECT_TRUE(a.receive('R')); EXPECT_TRUE(b.receive('R'));
    EXPECT_TRUE(a.send('W')); EXPECT_TRUE(a.receive());
    EXPECT_TRUE(b.send('W')); EXPECT_TRUE(b.receive());
    mmap_sink cleaner(dir, "cleaner", policy::yyyy_MM_dd);
    // Deletion races with real appends. Records written before deletion may be
    // intentionally removed, but every surviving record must remain readable.
    EXPECT_TRUE(a.send('W')); EXPECT_TRUE(b.send('W'));
    cleaner.remove_all();
    EXPECT_TRUE(a.receive()); EXPECT_TRUE(b.receive());
    for (auto &record : mxtest::parse_dir(dir)) {
        EXPECT_EQ(record["error_code"], std::string("0"));
    }
    cleaner.remove_all();
    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    EXPECT_TRUE(files.empty());
    EXPECT_TRUE(a.send('W')); EXPECT_TRUE(b.send('W'));
    EXPECT_TRUE(a.receive()); EXPECT_TRUE(b.receive());
    check_records(mxtest::parse_dir(dir), 300, false, 2);
    EXPECT_TRUE(a.finish()); EXPECT_TRUE(b.finish());
    log_msg msg(level::info, "after-cleanup", nullptr, "reopened", false);
    EXPECT_EQ(cleaner.log(msg), 0);
}

MX_TEST(multiprocess, killed_writer_releases_locks_and_uncommitted_tail_is_ignored) {
    std::string dir = mxtest::temp_dir("ipc_crash");
    worker survivor(dir, 1, 10), killed(dir, 2, 10);
    EXPECT_TRUE(survivor.receive('R')); EXPECT_TRUE(killed.receive('R'));
    EXPECT_TRUE(survivor.send('W')); EXPECT_TRUE(survivor.receive());
    EXPECT_TRUE(killed.send('T')); EXPECT_TRUE(killed.receive('L'));
    EXPECT_TRUE(survivor.send('W'));
    EXPECT_FALSE(survivor.pending(100)); // Must wait for the other process's lock.
    EXPECT_TRUE(killed.kill_and_wait());
    EXPECT_TRUE(survivor.receive());
    check_records(mxtest::parse_dir(dir), 20);
    EXPECT_TRUE(survivor.finish());
}

MX_TEST(multiprocess, legacy_reads_do_not_create_coordination_files) {
    std::string dir = mxtest::temp_dir("ipc_legacy_read");
    { mmap_sink sink(dir, "legacy", policy::yyyy_MM_dd);
      log_msg msg(level::info, "legacy", nullptr, "read-only export", false);
      EXPECT_EQ(sink.log(msg), 0); }
    std::string lock_path = dir + mxlogger::ipc::lock_filename;
    EXPECT_EQ(mxlogger::remove_file(lock_path.c_str()), 0);
    #ifndef _WIN32
    EXPECT_EQ(::chmod(dir.c_str(), 0555), 0);
    #endif
    auto records = mxtest::parse_dir(dir);
    #ifndef _WIN32
    EXPECT_EQ(::chmod(dir.c_str(), 0755), 0);
    #endif
    EXPECT_EQ(records.size(), size_t(1));
    EXPECT_FALSE(mxlogger::path_exists(lock_path.c_str()));
}

MX_TEST(multiprocess, killed_process_does_not_leave_stale_active_file_registration) {
    std::string dir = mxtest::temp_dir("ipc_dead_lease");
    worker other(dir, 1, 1, false, "other");
    EXPECT_TRUE(other.receive('R'));
    std::string active = mxtest::first_mx_path(dir);
    mmap_sink cleaner(dir, "cleaner", policy::yyyy_MM_dd);
    cleaner.remove_before_all();
    EXPECT_TRUE(mxlogger::path_exists(active.c_str()));
    EXPECT_TRUE(other.kill_and_wait());
    cleaner.remove_before_all();
    EXPECT_FALSE(mxlogger::path_exists(active.c_str()));
}

MX_TEST(multiprocess, independent_directories_do_not_block_each_other) {
    std::string first = mxtest::temp_dir("ipc_independent_a");
    std::string second = mxtest::temp_dir("ipc_independent_b");
    mxlogger::ipc::directory_lock directory_lock(first);
    mxlogger::ipc::scoped_lock held(directory_lock);
    EXPECT_TRUE(bool(held));
    worker other(second, 1, 1);
    EXPECT_TRUE(other.receive('R'));
    EXPECT_TRUE(other.send('W')); EXPECT_TRUE(other.receive());
    check_records(mxtest::parse_dir(second), 1);
    EXPECT_TRUE(other.finish());
}

MX_TEST(multiprocess, lock_failure_never_falls_back_to_unlocked_writes) {
    std::string dir = mxtest::temp_dir("ipc_lock_failure");
    EXPECT_TRUE(std::filesystem::create_directory(std::filesystem::u8path(dir + mxlogger::ipc::lock_filename)));
    mmap_sink sink(dir, "blocked", policy::yyyy_MM_dd);
    log_msg msg(level::info, "blocked", nullptr, "must not write", false);
    EXPECT_EQ(sink.log(msg), -4);
    EXPECT_TRUE(mxtest::first_mx_path(dir).empty());
}

MX_TEST(multiprocess, invalid_committed_length_does_not_erase_existing_file) {
    std::string dir = mxtest::temp_dir("ipc_bad_header");
    { mmap_sink sink(dir, "bad", policy::yyyy_MM_dd); }
    std::string path = mxtest::first_mx_path(dir);
    mxlogger::files::native_file file;
    EXPECT_TRUE(file.open(path));
    uint32_t invalid = UINT32_MAX;
    EXPECT_EQ(file.write_at(&invalid, 4, 0), std::ptrdiff_t(4));
    file.close();
    std::string before = mxtest::slurp(path);
    mmap_sink sink(dir, "bad", policy::yyyy_MM_dd);
    log_msg msg(level::info, "bad", nullptr, "must not erase", false);
    EXPECT_EQ(sink.log(msg), -3);
    EXPECT_EQ(mxtest::slurp(path), before);
}
#endif
