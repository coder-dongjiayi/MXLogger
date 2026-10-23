#include "mxlogger_interprocess.hpp"
#if MXLOGGER_MACOS_MULTIPROCESS
#include "test_support.hpp"
#include "sink/mmap_sink.hpp"
#include "log_msg.hpp"
#include <mach-o/dyld.h>
#include <poll.h>
#include <spawn.h>
#include <sys/wait.h>
#include <signal.h>
#include <set>

extern char **environ;
using mxlogger::sinks::mmap_sink;
using mxlogger::details::log_msg;
using mxtest::record_list;
static const char *crypt_key = "ipc-key-12345678";
static const char *crypt_iv = "short-iv";

// Exec fresh processes rather than inheriting mmap offsets, mutexes or lock fds.
// Pipes provide deterministic barriers; no scheduling sleeps are needed.
class worker {
public:
    worker(const std::string &dir, int id, int count = 150, bool crypt = false,
           const std::string &filename = "shared") {
        int control[2], report[2];
        if (::pipe(control) != 0) return;
        if (::pipe(report) != 0) { ::close(control[0]); ::close(control[1]); return; }
        fcntl(control[1], F_SETFD, FD_CLOEXEC);
        fcntl(report[0], F_SETFD, FD_CLOEXEC);
        uint32_t size = 4096;
        char executable[4096];
        if (_NSGetExecutablePath(executable, &size) != 0) {
            for (int fd : {control[0], control[1], report[0], report[1]}) ::close(fd);
            return;
        }
        std::vector<std::string> args = {executable, "--ipc-worker", dir, filename,
            std::to_string(id), std::to_string(count), crypt ? "1" : "0",
            std::to_string(control[0]), std::to_string(report[1])};
        std::vector<char *> argv;
        for (auto &arg : args) argv.push_back(&arg[0]);
        argv.push_back(nullptr);
        posix_spawn_file_actions_t actions;
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_addclose(&actions, control[1]);
        posix_spawn_file_actions_addclose(&actions, report[0]);
        int result = posix_spawn(&pid_, executable, &actions, nullptr, argv.data(), environ);
        posix_spawn_file_actions_destroy(&actions);
        ::close(control[0]); ::close(report[1]);
        if (result != 0) {
            ::close(control[1]); ::close(report[0]); pid_ = -1; return;
        }
        control_ = control[1]; report_ = report[0];
    }
    ~worker() {
        if (pid_ > 0) { ::kill(pid_, SIGKILL); int status; ::waitpid(pid_, &status, 0); }
        if (control_ >= 0) ::close(control_);
        if (report_ >= 0) ::close(report_);
    }
    bool send(char command) { return control_ >= 0 && ::write(control_, &command, 1) == 1; }
    bool pending(int timeout = 10000) {
        struct pollfd fd{report_, POLLIN, 0};
        return report_ >= 0 && ::poll(&fd, 1, timeout) > 0 && (fd.revents & POLLIN);
    }
    bool receive(char expected = 'D') {
        char response = 0;
        return pending() && ::read(report_, &response, 1) == 1 && response == expected;
    }
    bool finish() {
        if (!send('Q') || !receive('Q')) return false;
        return reap(false);
    }
    bool kill_and_wait() {
        if (pid_ <= 0 || ::kill(pid_, SIGKILL) != 0) return false;
        return reap(true);
    }
private:
    bool reap(bool killed) {
        int status = 0;
        pid_t result;
        do { result = ::waitpid(pid_, &status, 0); } while (result < 0 && errno == EINTR);
        if (result <= 0) return false;
        pid_ = -1;
        return killed ? WIFSIGNALED(status) && WTERMSIG(status) == SIGKILL
                      : WIFEXITED(status) && WEXITSTATUS(status) == 0;
    }
    pid_t pid_ = -1;
    int control_ = -1, report_ = -1;
};

int mxlogger_process_worker(int argc, char **argv) {
    if (argc != 9) return 20;
    const std::string dir = argv[2];
    const int id = atoi(argv[4]), count = atoi(argv[5]);
    const bool crypt = atoi(argv[6]) != 0;
    const int control = atoi(argv[7]), report = atoi(argv[8]);
    {
        mmap_sink sink(dir, argv[3], policy::yyyy_MM_dd);
        if (crypt) sink.init_aescfb(crypt_key, crypt_iv);
        if (!sink.error_record.empty()) return 21;
        if (::write(report, "R", 1) != 1) return 22;
        int round = 0;
        char command;
        while (::read(control, &command, 1) == 1) {
            if (command == 'Q') break;
            if (command == 'H') {
                sink.add_file_heder("shared header");
            } else if (command == 'W') {
                for (int i = 0; i < count; ++i) {
                    std::string msg = std::to_string(id) + ":" + std::to_string(round) + ":" + std::to_string(i) + ":" + std::string(512, 'P');
                    log_msg record(level::info, "ipc", "tag", msg.c_str(), false);
                    if (sink.log(record) != 0) return 23;
                }
                ++round;
            } else if (command == 'T') {
                mxlogger::ipc::directory_lock directory_lock(dir);
                mxlogger::ipc::scoped_lock lock(directory_lock);
                if (!lock) return 24;
                std::string path = mxtest::first_mx_path(dir);
                int fd = ::open(path.c_str(), O_RDWR | O_CLOEXEC);
                uint32_t committed = 0;
                if (fd < 0 || ::pread(fd, &committed, 4, 0) != 4 ||
                    ::pwrite(fd, "uncommitted-tail", 16, 4 + committed) != 16) return 25;
                ::close(fd);
                if (::write(report, "L", 1) != 1) return 26;
                // The parent terminates us while the OS lock and data lease are held.
                while (true) ::pause();
            } else return 27;
            if (::write(report, "D", 1) != 1) return 28;
        }
    } // Release the data-file lease before acknowledging a graceful exit.
    return ::write(report, "Q", 1) == 1 ? 0 : 29;
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
    // B already mapped the initial page before A appended and expanded the file.
    EXPECT_TRUE(b.send('W')); EXPECT_TRUE(b.receive());
    check_records(mxtest::parse_dir(dir), 300);
    EXPECT_TRUE(a.finish()); EXPECT_TRUE(b.finish());
}

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
    EXPECT_EQ(::unlink(lock_path.c_str()), 0);
    EXPECT_EQ(::chmod(dir.c_str(), 0555), 0);
    auto records = mxtest::parse_dir(dir);
    EXPECT_EQ(::chmod(dir.c_str(), 0755), 0);
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
    EXPECT_EQ(::mkdir((dir + mxlogger::ipc::lock_filename).c_str(), 0755), 0);
    mmap_sink sink(dir, "blocked", policy::yyyy_MM_dd);
    log_msg msg(level::info, "blocked", nullptr, "must not write", false);
    EXPECT_EQ(sink.log(msg), -4);
    EXPECT_TRUE(mxtest::first_mx_path(dir).empty());
}

MX_TEST(multiprocess, invalid_committed_length_does_not_erase_existing_file) {
    std::string dir = mxtest::temp_dir("ipc_bad_header");
    { mmap_sink sink(dir, "bad", policy::yyyy_MM_dd); }
    std::string path = mxtest::first_mx_path(dir);
    int fd = ::open(path.c_str(), O_RDWR);
    uint32_t invalid = UINT32_MAX;
    EXPECT_EQ(::pwrite(fd, &invalid, 4, 0), ssize_t(4));
    ::close(fd);
    std::string before = mxtest::slurp(path);
    mmap_sink sink(dir, "bad", policy::yyyy_MM_dd);
    log_msg msg(level::info, "bad", nullptr, "must not erase", false);
    EXPECT_EQ(sink.log(msg), -3);
    EXPECT_EQ(mxtest::slurp(path), before);
}
#endif
