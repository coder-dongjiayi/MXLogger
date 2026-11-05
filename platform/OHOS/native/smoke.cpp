#include "smoke.hpp"
#include "mxlogger_ffi.h"
#include "mxlogger.hpp"
#include "json/cJSON.h"
#include <algorithm>
#include <memory>
#include <stdexcept>
#include <vector>
#include <unistd.h>

namespace mxlogger_poc {
namespace {
using Json = std::unique_ptr<cJSON, decltype(&cJSON_Delete)>;
constexpr const char *key = "poc-test-key-1234";
constexpr const char *iv = "poc-test-iv--1234";

std::string take_string(char *value) {
    if (!value) throw std::runtime_error("FFI returned a null string");
    std::unique_ptr<char, decltype(&flutter_mxlogger_free_string)>
        owner(value, flutter_mxlogger_free_string);
    return value;
}

struct Logger {
    const char *ns;
    const std::string &directory;
    void *handle = nullptr;
    ~Logger() { close(); }
    void close() {
        if (handle) flutter_mxlogger_destroy(ns, directory.c_str());
        handle = nullptr;
    }
    void open(bool encrypted) {
        handle = flutter_mxlogger_initialize(ns, directory.c_str(), "yyyy_MM_dd", "poc",
            nullptr, encrypted ? key : nullptr, encrypted ? iv : nullptr);
        if (!handle) throw std::runtime_error("logger initialization failed");
    }
};

struct Files {
    char ***rows = nullptr;
    uint32_t **lengths = nullptr;
    int32_t count = 0;
    ~Files() { flutter_mxlogger_free_logfiles(count, rows, lengths); }
};
struct Records {
    char **rows = nullptr;
    uint32_t *lengths = nullptr;
    int32_t count = 0;
    ~Records() { flutter_mxlogger_free_logmsg(count, rows, lengths); }
};

std::vector<std::string> read(void *handle, bool encrypted, std::vector<std::string> &paths) {
    paths.clear();
    Files files;
    files.count = flutter_mxlogger_get_logfiles(handle, &files.rows, &files.lengths);
    const auto directory = take_string(flutter_mxlogger_get_diskcache_path(handle));
    std::vector<std::string> messages;
    for (int32_t i = 0; i < files.count; ++i) {
        const std::string name(files.rows[i][0], files.lengths[i][0]);
        if (name.size() < 3 || name.substr(name.size() - 3) != ".mx") continue;
        const auto path = directory + (directory.back() == '/' ? "" : "/") + name;
        paths.push_back(path);
        Records records;
        if (flutter_mxlogger_select_logmsg(path.c_str(), encrypted ? key : nullptr,
                encrypted ? iv : nullptr, &records.count, &records.rows, &records.lengths) != 0) {
            throw std::runtime_error("FFI read failed: " + path);
        }
        for (int32_t j = 0; j < records.count; ++j) {
            Json row(cJSON_Parse(records.rows[j]), cJSON_Delete);
            const auto *error = cJSON_GetObjectItemCaseSensitive(row.get(), "error_code");
            const auto *message = cJSON_GetObjectItemCaseSensitive(row.get(), "msg");
            if (!cJSON_IsString(error) || std::string(error->valuestring) != "0" ||
                !cJSON_IsString(message)) {
                throw std::runtime_error("log record decode failed: " + path);
            }
            messages.emplace_back(message->valuestring);
        }
    }
    return messages;
}
}

std::string run(const std::string &directory, bool encrypted) {
    if (directory.empty() || directory.front() != '/')
        throw std::invalid_argument("an absolute sandbox directory is required");
    Logger logger{encrypted ? "poc_encrypted" : "poc_plain", directory};
    logger.open(encrypted);
    const auto token = take_string(flutter_mxlogger_get_loggerToken(logger.handle));
    auto *core = mx_logger::global_for_loggerToken(token.c_str());
    if (!core || static_cast<void *>(core) != logger.handle)
        throw std::runtime_error("FFI and native code did not resolve the same Core instance");

    std::vector<std::string> paths;
    const auto before = read(logger.handle, encrypted, paths);
    const auto suffix = std::to_string(before.size() + 1);
    const auto ffi_message = std::string("OHOS POC FFI 中文 ✅ #") + suffix;
    const auto native_message = std::string("OHOS POC native 中文 ✅ #") + suffix;
    if (flutter_mxlogger_log(logger.handle, "ohos_poc", 1, ffi_message.c_str(), "ffi") != 0 ||
        core->log(1, "ohos_poc", native_message.c_str(), "native", true) != 0) {
        throw std::runtime_error("write failed: " + take_string(flutter_mxlogger_get_error_desc(logger.handle)));
    }
    core->flush();
    logger.close();
    logger.open(encrypted);
    const auto after = read(logger.handle, encrypted, paths);
    if (after.size() != before.size() + 2 ||
        std::count(after.begin(), after.end(), ffi_message) != 1 ||
        std::count(after.begin(), after.end(), native_message) != 1) {
        throw std::runtime_error("reopen read-back did not match both written records");
    }
    for (const auto &message : before) {
        if (std::find(after.begin(), after.end(), message) == after.end())
            throw std::runtime_error("a previously committed record was lost");
    }

    Json report(cJSON_CreateObject(), cJSON_Delete);
    cJSON_AddBoolToObject(report.get(), "passed", true);
    cJSON_AddStringToObject(report.get(), "coreVersion", flutter_mxlogger_core_version());
    cJSON_AddNumberToObject(report.get(), "pid", getpid());
    cJSON_AddBoolToObject(report.get(), "encrypted", encrypted);
    cJSON_AddBoolToObject(report.get(), "sharedCore", true);
    cJSON_AddNumberToObject(report.get(), "previousCount", static_cast<double>(before.size()));
    cJSON_AddNumberToObject(report.get(), "readBackCount", static_cast<double>(after.size()));
    cJSON_AddStringToObject(report.get(), "loggerToken", token.c_str());
    cJSON_AddStringToObject(report.get(), "directory", directory.c_str());
    auto *files = cJSON_AddArrayToObject(report.get(), "files");
    for (const auto &path : paths) cJSON_AddItemToArray(files, cJSON_CreateString(path.c_str()));
    char *json = cJSON_PrintUnformatted(report.get());
    if (!json) throw std::bad_alloc();
    std::unique_ptr<char, decltype(&cJSON_free)> serialized(json, cJSON_free);
    return json;
}
}
