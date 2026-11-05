#include "mxlogger_ohos.h"
#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

void check(bool value, const char *message) {
    if (!value) throw std::runtime_error(std::string(message) + ": " + mxlogger_ohos_last_error());
}
std::string take(char *value) {
    check(value != nullptr, "string allocation/access");
    std::string result(value);
    flutter_mxlogger_free_string(value);
    return result;
}
struct Handle {
    void *value;
    ~Handle() { mxlogger_ohos_destroy_handle(value); flutter_mxlogger_release_handle(value); }
};
void *open(const std::string &root, const std::string &name, const char *key = nullptr) {
    auto h = flutter_mxlogger_initialize(name.c_str(), root.c_str(), "yyyy_MM_dd", "sdk", nullptr, key, nullptr);
    check(h != nullptr, "initialize"); return h;
}
std::string first_file(void *handle) {
    char ***rows = nullptr; uint32_t **lengths = nullptr;
    const auto count = flutter_mxlogger_get_logfiles(handle, &rows, &lengths);
    check(count == 1, "one active file");
    std::string name(rows[0][0]);
    flutter_mxlogger_free_logfiles(count, rows, lengths);
    return name;
}
int count(void *handle) {
    const auto path = take(flutter_mxlogger_get_diskcache_path(handle)) + first_file(handle);
    int32_t size = 0; char **rows = nullptr; uint32_t *lengths = nullptr;
    check(flutter_mxlogger_select_logmsg(path.c_str(), nullptr, nullptr, &size, &rows, &lengths) == 0, "read C ABI rows");
    flutter_mxlogger_free_logmsg(size, rows, lengths);
    return size;
}

int main() {
    try {
        const auto root = std::filesystem::temp_directory_path() /
            ("mxlogger-sdk-" + std::to_string(std::chrono::steady_clock::now().time_since_epoch().count()));
        std::filesystem::create_directories(root);
        Handle a{open(root.string(), "shared")};
        Handle b{open(root.string() + "/./", "shared")};
        check(a.value != b.value, "independently owned wrappers");
        const auto token = take(flutter_mxlogger_get_loggerToken(a.value));
        check(token == take(flutter_mxlogger_get_loggerToken(b.value)), "canonical shared identity");
        check(mxlogger_ohos_configure(a.value, 0, 2) == 0, "configure level");
        check(take(mxlogger_ohos_snapshot(b.value)).find("\"level\":2") != std::string::npos, "alias sees actual configuration");
        check(mxlogger_ohos_configure(a.value, 4, 5000000000LL) == 0, "64-bit disk limit");
        check(take(mxlogger_ohos_snapshot(b.value)).find("5000000000") != std::string::npos, "64-bit limit readback");
        check(flutter_mxlogger_log(a.value, "test", 1, "filtered", "") == 0, "filtered return code");
        check(flutter_mxlogger_log(a.value, "test", 2, "保留 中文 ✅", "") == 0, "write UTF-8");
        check(count(a.value) == 1, "level filtering");
        check(mxlogger_ohos_configure(b.value, 1, 0) == 0, "disable");
        flutter_mxlogger_log(a.value, "test", 4, "disabled", "");
        check(count(b.value) == 1, "disable shared behavior");
        mxlogger_ohos_configure(a.value, 1, 1);
        check(mxlogger_ohos_configure(a.value, 3, -1) == -1 && mxlogger_ohos_last_error_code() == 1, "reject invalid config");
        check(flutter_mxlogger_initialize("shared", root.c_str(), "yyyy_MM_dd", "sdk", nullptr, "different", nullptr) == nullptr
            && mxlogger_ohos_last_error_code() == 3, "conflicting initialization rejected");
        check(flutter_mxlogger_initialize("../bad", root.c_str(), nullptr, nullptr, nullptr, nullptr, nullptr) == nullptr, "reject namespace traversal");
        check(flutter_mxlogger_initialize("bad", "/dev/null/invalid", nullptr, nullptr, nullptr, nullptr, nullptr) == nullptr, "reject inaccessible directory");
        check(mxlogger_ohos_read_file(a.value, "../escape.mx") == nullptr, "reject file traversal");
        Handle attached{mxlogger_ohos_attach(token.c_str())};
        check(attached.value != nullptr, "attach by token");
        check(flutter_mxlogger_log_loggerToken(token.c_str(), "test", 3, "token", "") == 0, "token write");
        check(count(attached.value) == 2, "shared token data");

        mxlogger_ohos_destroy_handle(a.value);
        check(!mxlogger_ohos_is_valid(b.value), "destroy invalidates every alias");
        check(flutter_mxlogger_log(b.value, "test", 4, "stale", "") == -4, "closed write fails safely");
        Handle fresh{open(root.string(), "shared")};
        mxlogger_ohos_destroy_handle(b.value);
        check(mxlogger_ohos_is_valid(fresh.value), "old generation cannot destroy reopened session");
        check(count(fresh.value) == 2, "reopen preserves committed data");
        check(mxlogger_ohos_read_file(fresh.value, first_file(fresh.value).c_str()) != nullptr, "read managed file");
        // Exercise paired ownership without leaking the test read result.
        take(mxlogger_ohos_read_file(fresh.value, first_file(fresh.value).c_str()));

        for (int round = 0; round < 25; ++round) {
            Handle racing{open(root.string(), "race" + std::to_string(round))};
            std::atomic<bool> start{false};
            std::atomic<int> completed{0}, rejected{0};
            std::vector<std::thread> writers;
            for (int thread = 0; thread < 4; ++thread) writers.emplace_back([&] {
                while (!start.load()) std::this_thread::yield();
                for (int i = 0; i < 100; ++i) {
                    const auto result = flutter_mxlogger_log(racing.value, "race", 1, "in-flight", "worker");
                    if (result == 0) ++completed;
                    else if (result == -4 && mxlogger_ohos_last_error_code() == 2) ++rejected;
                    else std::terminate();
                }
            });
            start = true;
            std::this_thread::yield();
            mxlogger_ohos_destroy_handle(racing.value);
            for (auto &writer : writers) writer.join();
            check(completed + rejected == 400, "all concurrent operations accounted for");
            check(!mxlogger_ohos_is_valid(racing.value), "race ended closed");
            Handle next{open(root.string(), "race" + std::to_string(round))};
            const int before = count(next.value);
            check(before == completed, "only successful operations committed");
            mxlogger_ohos_destroy_handle(racing.value);
            check(mxlogger_ohos_is_valid(next.value), "race stale wrapper cannot close new generation");
        }
        Handle encrypted{open(root.string(), "encrypted", "poc-test-key-1234")};
        check(flutter_mxlogger_log(encrypted.value, "aes", 1, "加密 中文 ✅", "") == 0, "encrypted write");
        check(take(mxlogger_ohos_read_file(encrypted.value, first_file(encrypted.value).c_str())).find("加密") != std::string::npos, "encrypted read");
        for (int mode = 0; mode < 3; ++mode) {
            const auto current = first_file(encrypted.value);
            const auto old = std::filesystem::path(take(flutter_mxlogger_get_diskcache_path(encrypted.value))) / "old.mx";
            std::ofstream(old.string()) << "inactive";
            if (mode == 0) {
                mxlogger_ohos_configure(encrypted.value, 4, 1);
                flutter_mxlogger_remove_expire_data(encrypted.value);
            } else if (mode == 1) flutter_mxlogger_remove_before_all_data(encrypted.value);
            else flutter_mxlogger_remove_all(encrypted.value);
            check(!std::filesystem::exists(old), "inactive file removed");
            check(first_file(encrypted.value) == current, "active file retained");
        }
        std::cout << "PASS: managed C ABI contracts; aliases; UTF-8/AES; 64-bit config; cleanup; 10000 concurrent writes vs destroy\n";
        return 0;
    } catch (const std::exception &error) {
        std::cerr << "FAIL: " << error.what() << '\n'; return 1;
    }
}
