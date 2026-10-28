#include "demo_model.hpp"
#include "demo_process.hpp"
#include "mxlogger_util.hpp"
#include "mxlogger_build_config.h"
#include "json/cJSON.h"
#include <algorithm>
#include <chrono>
#include <cctype>
#include <iomanip>
#include <memory>
#include <mutex>
#include <set>
#include <sstream>
#include <stdexcept>
#include <thread>

namespace demo {
namespace fs = std::filesystem;
using Utility = mxlogger::util::mxlogger_util;
namespace {
using Json = std::unique_ptr<cJSON, decltype(&cJSON_Delete)>;
void check(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
}
bool leaf(const std::string& name) {
    if (name.empty() || name.size() > 100 || name == "." || name == ".." ||
        name.back() == '.' || name.back() == ' ') return false;
    for (unsigned char c : name) if (c < 32 || std::string("/\\:*?\"<>|").find(c) != std::string::npos) return false;
    auto stem = name.substr(0, name.find('.'));
    std::transform(stem.begin(), stem.end(), stem.begin(), [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
    const std::set<std::string> reserved = {"CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"};
    return reserved.count(stem) == 0;
}
void readable(const Records& records) {
    for (const auto& row : records) check(field(row, "error_code") == "0", "Cannot decode existing logs. Check AES key/IV or choose a new namespace. / 日志解码失败，请检查密钥或更换命名空间。");
}
std::string json_string(cJSON* json) {
    char* value = cJSON_PrintUnformatted(json);
    check(value != nullptr, "JSON allocation failed");
    std::string result(value);
    cJSON_free(value);
    return result;
}
}
std::string field(const Record& row, const char* key) {
    auto found = row.find(key);
    return found == row.end() ? std::string{} : found->second;
}
std::string unique_id() {
    static std::atomic<unsigned> counter{0};
    return std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()) + "-" + std::to_string(counter++);
}
void Config::validate() const {
    check(!root.empty() && root.size() < 20000, "Choose a log root directory. / 请选择日志根目录。");
    check(leaf(name_space) && leaf(file_name), "Invalid namespace/file name. / 命名空间或文件名不合法。");
    check(!encrypted || (key.size() == 16 && (iv.empty() || iv.size() == 16)), "AES key must be 16 UTF-8 bytes; IV may be empty or 16 bytes. / Key 需要 16 字节，IV 可留空或 16 字节。");
    check(policy == "yyyy_MM_dd_HH" || policy == "yyyy_MM_dd" || policy == "yyyy_ww" || policy == "yyyy_MM", "Invalid storage policy");
    check(level >= 0 && level <= 4 && max_age >= 0 && max_size >= 0, "Invalid logger settings");
}
Session::Session(Config config, bool validate_existing) : config_(std::move(config)) {
    config_.validate();
    config_.root = fs::absolute(fs::u8path(config_.root)).lexically_normal().u8string();
    const auto directory = fs::u8path(config_.root) / fs::u8path(config_.name_space);
    // Avoid accidentally mixing plaintext or different keys in the same dataset.
    if (validate_existing && fs::exists(directory)) {
        for (const auto& entry : fs::directory_iterator(directory)) {
            if (!entry.is_regular_file() || entry.path().extension() != ".mx") continue;
            Records records;
            Utility::select_log_form_path(entry.path().u8string().c_str(), &records, config_.crypt_key(), config_.crypt_iv());
            readable(records);
        }
    }
    fs::create_directories(fs::u8path(config_.root));
    open();
}
Session::~Session() { close(); }
void Session::open() {
    check(logger_ == nullptr, "Session already open");
    const auto existing = mx_logger::global_for_loggerToken(mx_logger::md5(config_.name_space.c_str(), config_.root.c_str()).c_str());
    check(existing == nullptr, "This process already owns the requested namespace");
    logger_ = mx_logger::initialize_namespace(config_.name_space.c_str(), config_.root.c_str(), config_.policy.c_str(),
        config_.file_name.c_str(), "{\"platform\":\"Windows\",\"appVersion\":\"2.2.0\",\"from\":\"native-demo\"}", config_.crypt_key(), config_.crypt_iv());
    check(logger_ != nullptr, "Logger initialization failed");
    const char* error = logger_->error_desc();
    if (error && *error) { const std::string message(error); close(); throw std::runtime_error(message); }
    settings(config_.enabled, config_.console, config_.level, config_.max_age, config_.max_size);
}
void Session::close() {
    if (!logger_) return;
    mx_logger::delete_namespace(config_.name_space.c_str(), config_.root.c_str());
    logger_ = nullptr;
}
std::string Session::path() const { return logger_->diskcache_path(); }
std::string Session::token() const { return logger_->logger_token(); }
Records Session::files() const {
    Records result;
    const auto directory = path();
    check(Utility::select_logfiles_dir(directory.c_str(), &result) >= 0, "Cannot list log directory");
    result.erase(std::remove_if(result.begin(), result.end(), [](const Record& row) { return fs::u8path(field(row, "name")).extension() != ".mx"; }), result.end());
    std::sort(result.begin(), result.end(), [](const Record& a, const Record& b) { return field(a, "name") < field(b, "name"); });
    return result;
}
Records Session::read(const std::string& file) const {
    check(fs::u8path(file).filename().u8string() == file && fs::u8path(file).extension() == ".mx", "Invalid log file name");
    Records records;
    const auto file_path = (fs::u8path(path()) / fs::u8path(file)).u8string();
    Utility::select_log_form_path(file_path.c_str(), &records, config_.crypt_key(), config_.crypt_iv());
    return records;
}
Records Session::all_records() const {
    Records result;
    for (const auto& file : files()) {
        auto rows = read(field(file, "name"));
        readable(rows);
        result.insert(result.end(), rows.begin(), rows.end());
    }
    return result;
}
void Session::settings(bool enabled, bool console, int level, long age, long size) {
    check(level >= 0 && level <= 4 && age >= 0 && size >= 0, "Invalid logger settings");
    config_.enabled = enabled;
    config_.console = console && MXLOGGER_CONSOLE_ENABLED;
    config_.level = level; config_.max_age = age; config_.max_size = size;
    logger_->set_enable(enabled);
    logger_->set_enable_console(config_.console);
    logger_->set_log_level(level);
    logger_->set_file_max_age(age);
    logger_->set_file_max_size(size);
}
void Session::write(int level, const std::string& message, const std::string& tag, bool token_api, bool main_thread) {
    auto* target = token_api ? mx_logger::global_for_loggerToken(token().c_str()) : logger_;
    check(target != nullptr, "Token lookup failed");
    const auto result = target->log(level, "MXLoggerDemo", message.c_str(), tag.c_str(), main_thread);
    if (result != 0) {
        const char* error = target->error_desc();
        throw std::runtime_error("Write failed (" + std::to_string(result) + "): " + (error ? error : ""));
    }
}
void Session::sample(int level, bool json, bool token_api) {
    write(level, json ? "{\"url\":\"https://example.com/api\",\"method\":\"GET\",\"status\":200,\"data\":{\"message\":\"你好，Windows\"}}" : "Hello MXLogger · Windows 原生 Demo · " + unique_id(),
          json ? "Network" : (token_api ? "Token" : "WindowsDemo"), token_api);
}
void Session::rebuild() { close(); open(); }
void Session::require_enabled() const {
    check(logger_->is_enable(), "Enable logging before running this action. / 请先开启日志写入。");
}
std::string Session::benchmark(int count, Progress& progress) {
    require_enabled();
    progress.total = count; progress.completed = 0;
    const bool console = logger_->is_enable_console();
    logger_->set_enable_console(false);
    const auto start = std::chrono::steady_clock::now();
    try {
        for (int i = 0; i < count; ++i) {
            if (progress.cancel) throw std::runtime_error("Cancelled / 已取消");
            write(config_.level, "benchmark " + std::to_string(i), "Benchmark");
            progress.completed = i + 1;
        }
    } catch (...) { logger_->set_enable_console(console); throw; }
    logger_->set_enable_console(console);
    const auto seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    std::ostringstream text;
    text << count << " writes / 条, " << std::fixed << std::setprecision(3) << seconds << " s, "
         << static_cast<long long>(count / std::max(0.000001, seconds)) << " records/s (flush excluded)";
    return text.str();
}
void Session::sequence(const std::string& run, int worker, int count, Progress* progress) {
    for (int i = 0; i < count; ++i) {
        if (progress && progress->cancel) throw std::runtime_error("Cancelled / 已取消");
        write(config_.level, std::to_string(worker) + ":" + std::to_string(i), run);
        if (progress) ++progress->completed;
    }
}
void Session::verify_sequence(const std::string& run, int workers, int count) const {
    std::vector<int> seen(static_cast<size_t>(workers), 0);
    for (const auto& record : all_records()) {
        if (field(record, "tag") != run) continue;
        const auto message = field(record, "msg");
        auto colon = message.find(':');
        check(colon != std::string::npos, "Invalid sequence record");
        int worker = std::stoi(message.substr(0, colon));
        int sequence = std::stoi(message.substr(colon + 1));
        check(worker >= 0 && worker < workers && sequence == seen[static_cast<size_t>(worker)], "Sequence mismatch / 日志顺序校验失败");
        ++seen[static_cast<size_t>(worker)];
    }
    for (int found : seen) check(found == count, "Record count mismatch / 日志数量校验失败");
}
std::string Session::threads(int count, Progress& progress) {
    require_enabled();
    progress.total = count * 4; progress.completed = 0;
    const auto run = "threads-" + unique_id();
    std::exception_ptr error;
    std::mutex error_mutex;
    std::vector<std::thread> threads;
    try {
        for (int t = 0; t < 4; ++t) threads.emplace_back([&, t] {
            try { sequence(run, t, count, &progress); }
            catch (...) { std::lock_guard<std::mutex> lock(error_mutex); if (!error) error = std::current_exception(); }
        });
    } catch (...) {
        for (auto& thread : threads) thread.join();
        throw;
    }
    for (auto& thread : threads) thread.join();
    if (error) std::rethrow_exception(error);
    logger_->flush();
    verify_sequence(run, 4, count);
    return "4 threads / 线程: " + std::to_string(4 * count) + " records, count + per-thread order PASS / 数量与线程内顺序通过";
}
std::string Session::processes(int count, Progress& progress) {
    require_enabled();
    progress.total = count * 2; progress.completed = 0;
    const auto run = "processes-" + unique_id();
    Child child(encode_config(config_));
    check(child.receive(progress, std::chrono::seconds(20)) == "READY", "Worker failed to initialize");
    child.send(run + " " + std::to_string(count));
    sequence(run, 0, count, &progress);
    check(child.receive(progress, std::chrono::seconds(60)) == "OK", "Worker write failed");
    child.finish(progress, std::chrono::seconds(10));
    progress.completed = count * 2;
    logger_->flush();
    verify_sequence(run, 2, count);
    return "2 processes / 进程: " + std::to_string(2 * count) + " records, count + per-process order PASS / 数量与进程内顺序通过";
}
std::string encode_config(const Config& c) {
    Json object(cJSON_CreateObject(), cJSON_Delete);
    check(object != nullptr, "JSON allocation failed");
    for (const auto& pair : std::vector<std::pair<const char*, std::string>>{{"root", c.root}, {"namespace", c.name_space}, {"file", c.file_name}, {"policy", c.policy}, {"key", c.key}, {"iv", c.iv}})
        cJSON_AddStringToObject(object.get(), pair.first, pair.second.c_str());
    cJSON_AddBoolToObject(object.get(), "encrypted", c.encrypted);
    cJSON_AddNumberToObject(object.get(), "level", c.level);
    return json_string(object.get());
}
Config decode_config(const std::string& json) {
    Json object(cJSON_Parse(json.c_str()), cJSON_Delete);
    check(cJSON_IsObject(object.get()), "Invalid worker configuration");
    auto string = [&](const char* key) {
        auto* value = cJSON_GetObjectItemCaseSensitive(object.get(), key);
        check(cJSON_IsString(value), "Invalid worker string"); return std::string(value->valuestring);
    };
    Config config;
    config.root = string("root"); config.name_space = string("namespace");
    config.file_name = string("file"); config.policy = string("policy");
    config.key = string("key"); config.iv = string("iv");
    auto* encryption = cJSON_GetObjectItemCaseSensitive(object.get(), "encrypted");
    auto* level = cJSON_GetObjectItemCaseSensitive(object.get(), "level");
    check(cJSON_IsBool(encryption) && cJSON_IsNumber(level), "Invalid worker settings");
    config.encrypted = cJSON_IsTrue(encryption); config.level = level->valueint;
    config.validate(); return config;
}
} // namespace demo
