#pragma once
#include "mxlogger.hpp"
#include <atomic>
#include <filesystem>
#include <map>
#include <string>
#include <vector>

namespace demo {
using Record = std::map<std::string, std::string>;
using Records = std::vector<Record>;
struct Config {
    std::string root;
    std::string name_space = "com.djy.mxlogger";
    std::string file_name = "mxlog";
    std::string policy = "yyyy_MM_dd_HH";
    bool encrypted = true;
    std::string key = "abcdefgabcdefgob";
    std::string iv = "abcdefgabcdefgcc";
    bool enabled = true;
    bool console = false;
    int level = 0;
    long max_age = 7 * 24 * 3600;
    long max_size = 10 * 1024 * 1024;
    void validate() const;
    const char* crypt_key() const { return encrypted ? key.c_str() : nullptr; }
    const char* crypt_iv() const { return encrypted && !iv.empty() ? iv.c_str() : nullptr; }
};
struct Progress {
    std::atomic<bool> cancel{false};
    std::atomic<int> completed{0};
    std::atomic<int> total{0};
};
class Session {
public:
    explicit Session(Config config, bool validate_existing = true);
    ~Session();
    Session(const Session&) = delete;
    Session& operator=(const Session&) = delete;
    const Config& config() const { return config_; }
    mx_logger* logger() const { return logger_; }
    std::string path() const;
    std::string token() const;
    Records files() const;
    Records read(const std::string& file) const;
    Records all_records() const;
    void settings(bool enabled, bool console, int level, long age, long size);
    void write(int level, const std::string& message, const std::string& tag = "WindowsDemo",
               bool token_api = false, bool main_thread = false);
    void sample(int level, bool json = false, bool token_api = false);
    void rebuild();
    std::string benchmark(int count, Progress& progress, double* elapsed = nullptr);
    std::string threads(int count_per_thread, Progress& progress);
    std::string processes(int count_per_process, Progress& progress);
    void sequence(const std::string& run, int worker, int count, Progress* progress = nullptr);
private:
    Config config_;
    mx_logger* logger_ = nullptr;
    void open();
    void close();
    void require_enabled() const;
    void verify_sequence(const std::string& run, int workers, int count) const;
};
std::string field(const Record& row, const char* key);
std::string unique_id();
std::string encode_config(const Config& config);
Config decode_config(const std::string& json);
int run_worker(const std::string& input, const std::string& output);
// Writes report.txt and report.json, returning a process exit code.
int smoke(const std::filesystem::path& report_dir);
int benchmark_report(const std::filesystem::path& report_dir);
} // namespace demo
