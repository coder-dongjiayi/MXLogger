#include "mxlogger_ohos.h"
#include "mxlogger_ffi_memory.hpp"
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
#include "json/cJSON.h"
#include <algorithm>
#include <array>
#include <climits>
#include <cmath>
#include <filesystem>
#include <map>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <vector>
#include <unistd.h>
#if defined(__OHOS__)
#include <sys/syscall.h>
#include <hilog/log.h>
#endif

namespace {
using Files = std::vector<std::map<std::string, std::string>>;
using Json = std::unique_ptr<cJSON, decltype(&cJSON_Delete)>;
using mxlogger::util::mxlogger_util;
struct Error : std::runtime_error {
    int code;
    Error(int c, const std::string &s) : std::runtime_error(s), code(c) {}
};
thread_local std::string last_error;
thread_local int last_code = 0;
template<class R, class F> R safe(R failure, F &&operation) noexcept {
    last_error.clear(); last_code = 0;
    try { return operation(); }
    catch (const Error &e) { last_error = e.what(); last_code = e.code; }
    catch (const std::exception &e) { last_error = e.what(); last_code = 4; }
    catch (...) { last_error = "unknown native error"; last_code = 4; }
    return failure;
}
void require(bool condition, const char *message) {
    if (!condition) throw Error(1, message);
}
std::string text(const char *s) { return s ? s : ""; }
std::string directory(const char *s) {
    require(s && std::filesystem::path(s).is_absolute(), "directory must be absolute");
    auto result = std::filesystem::path(s).lexically_normal().string();
    while (result.size() > 1 && result.back() == '/') result.pop_back();
    return result;
}
void component(const std::string &s) {
    require(!s.empty() && s != "." && s != ".." && s.find_first_of("/\\") == std::string::npos,
            "namespace and filename must be nonempty path components");
}
struct Session {
    std::mutex mutex;
    mx_logger *core = nullptr;
    std::string token;
    std::array<std::string, 5> config; // policy, filename, header, key, iv
    bool console = false;
    ~Session() { if (core) mx_logger::delete_namespace(token.c_str()); }
};
struct Handle { std::shared_ptr<Session> session; };
class Registry {
    std::mutex mutex_;
    std::unordered_map<std::string, std::shared_ptr<Session>> sessions_;
    std::unordered_map<void *, std::unique_ptr<Handle>> handles_;
    void *wrap(const std::shared_ptr<Session> &session) {
        auto handle = std::make_unique<Handle>();
        handle->session = session;
        void *id = handle.get();
        handles_.emplace(id, std::move(handle));
        return id;
    }
    void close_locked(const std::shared_ptr<Session> &session) {
        std::lock_guard<std::mutex> lock(session->mutex);
        if (session->core) {
            mx_logger::delete_namespace(session->token.c_str());
            session->core = nullptr;
        }
        sessions_.erase(session->token);
    }
public:
    void *initialize(const char *ns_arg, const char *dir, const char *policy,
                     const char *filename, const char *header, const char *key, const char *iv) {
        const auto ns = ns_arg ? std::string(ns_arg) : std::string("default");
        component(ns);
        const auto root = directory(dir);
        std::array<std::string, 5> config = {policy ? policy : "yyyy_MM_dd",
            filename ? filename : "mxlog", text(header), text(key), text(iv)};
        component(config[1]);
        require(config[0] == "yyyy_MM_dd" || config[0] == "yyyy_MM_dd_HH" ||
                config[0] == "yyyy_ww" || config[0] == "yyyy_MM", "invalid storage policy");
        const auto token = mx_logger::md5(ns.c_str(), root.c_str());
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = sessions_.find(token);
        if (found != sessions_.end()) {
            if (found->second->config != config)
                throw Error(3, "logger already exists with different initialization options");
            return wrap(found->second);
        }
        auto session = std::make_shared<Session>();
        session->token = token;
        session->config = config;
        session->core = mx_logger::initialize_namespace(ns.c_str(), root.c_str(), config[0].c_str(),
            config[1].c_str(), header, key && *key ? key : nullptr, iv && *iv ? iv : nullptr);
        if (!session->core || !std::string(session->core->error_desc()).empty())
            throw Error(4, "cannot initialize log files in the requested directory");
        session->core->set_enable_console(false); // OHOS console is emitted through HiLog below.
        sessions_.emplace(token, session);
        return wrap(session);
    }
    std::shared_ptr<Session> get(void *id) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = handles_.find(id);
        if (found == handles_.end()) throw Error(2, "invalid or released logger handle");
        return found->second->session;
    }
    void *attach(const char *token) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = sessions_.find(text(token));
        if (found == sessions_.end()) throw Error(2, "logger token is not active");
        return wrap(found->second);
    }
    std::shared_ptr<Session> by_token(const char *token) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = sessions_.find(text(token));
        if (found == sessions_.end()) throw Error(2, "logger token is not active");
        return found->second;
    }
    void close_token(const char *token) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = sessions_.find(text(token));
        if (found != sessions_.end()) {
            auto session = found->second; // erase must not invalidate the owning reference.
            close_locked(session);
        }
    }
    void close_handle(void *id) {
        std::lock_guard<std::mutex> lock(mutex_);
        auto found = handles_.find(id);
        if (found == handles_.end()) return;
        auto session = found->second->session;
        auto active = sessions_.find(session->token);
        // An old wrapper must never destroy a new generation with the same token.
        if (active != sessions_.end() && active->second == session) close_locked(session);
    }
    void release(void *id) {
        std::lock_guard<std::mutex> lock(mutex_);
        handles_.erase(id);
    }
};
Registry &registry() { static Registry value; return value; }
struct Access {
    std::shared_ptr<Session> session;
    std::unique_lock<std::mutex> lock;
    explicit Access(std::shared_ptr<Session> s) : session(std::move(s)), lock(session->mutex) {
        if (!session->core) throw Error(2, "logger has been destroyed");
    }
    explicit Access(void *id) : Access(registry().get(id)) {}
    mx_logger *operator->() const { return session->core; }
};
char *copy(const char *s) {
    auto result = mxlogger_ffi_detail::copy_string(s);
    if (!result) throw std::bad_alloc();
    return result;
}
char *serialize(cJSON *value) {
    auto result = cJSON_PrintUnformatted(value);
    if (!result) throw std::bad_alloc();
    return result;
}
Files files(mx_logger *core) {
    Files result;
    if (mxlogger_util::select_logfiles_dir(core->diskcache_path(), &result) != 0)
        throw Error(4, "cannot enumerate log directory");
    result.erase(std::remove_if(result.begin(), result.end(), [](const auto &row) {
        const auto &name = row.at("name");
        return name.size() < 3 || name.substr(name.size() - 3) != ".mx";
    }), result.end());
    return result;
}
Files records(const char *path, const char *key, const char *iv) {
    require(path && std::filesystem::is_regular_file(path), "log file does not exist");
    Files result;
    mxlogger_util::select_log_form_path(path, &result, key, iv);
    return result;
}
Json rows_json(const Files &rows) {
    Json result(cJSON_CreateArray(), cJSON_Delete);
    for (const auto &row : rows) {
        auto item = cJSON_CreateObject();
        for (const auto &field : row) cJSON_AddStringToObject(item, field.first.c_str(), field.second.c_str());
        cJSON_AddItemToArray(result.get(), item);
    }
    return result;
}
bool main_thread() {
#if defined(__OHOS__)
    return ::syscall(SYS_gettid) == ::getpid();
#else
    return false; // Host checks exercise concurrency; this is not a host SDK API.
#endif
}
int write(Access &access, int level, const char *name, const char *message, const char *tag) {
    require(level >= 0 && level <= 4 && message, "level must be 0..4 and message must be a string");
    const auto result = access->log(level, name, message, tag, main_thread());
    if (result != 0) {
        last_error = access->error_desc(); last_code = 4;
        return result; // Preserve Core's negative write codes for C ABI consumers.
    }
#if defined(__OHOS__)
    if (access.session->console && access->is_enable() && level >= access->log_level()) {
        const LogLevel levels[] = {LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR, LOG_FATAL};
        OH_LOG_Print(LOG_APP, levels[level], 0, "MXLogger", "[%{public}s] [%{public}s] %{public}s",
            name ? name : "mxlogger", tag ? tag : "", message);
    }
#endif
    return result;
}
}

const char *mxlogger_ohos_last_error() { return last_error.c_str(); }
int32_t mxlogger_ohos_last_error_code() { return last_code; }
const char *flutter_mxlogger_core_version() { return mx_logger::version(); }
void *flutter_mxlogger_initialize(const char *ns, const char *dir, const char *policy,
    const char *name, const char *header, const char *key, const char *iv) {
    return safe<void *>(nullptr, [&] { return registry().initialize(ns, dir, policy, name, header, key, iv); });
}
void *mxlogger_ohos_attach(const char *token) {
    return safe<void *>(nullptr, [&] { return registry().attach(token); });
}
void flutter_mxlogger_destroy(const char *ns, const char *dir) {
    safe<int>(0, [&] { registry().close_token(mx_logger::md5(ns ? ns : "default", directory(dir).c_str()).c_str()); return 1; });
}
void flutter_mxlogger_destroyWithLoggerToken(const char *token) {
    safe<int>(0, [&] { registry().close_token(token); return 1; });
}
void mxlogger_ohos_destroy_handle(void *handle) {
    safe<int>(0, [&] { registry().close_handle(handle); return 1; });
}
void flutter_mxlogger_release_handle(void *handle) { registry().release(handle); }
int32_t mxlogger_ohos_is_valid(void *handle) {
    return safe<int32_t>(0, [&] { Access access(handle); return 1; });
}
int32_t mxlogger_ohos_flush(void *handle) {
    return safe<int32_t>(-1, [&] { Access access(handle); access->flush(); return 0; });
}
int32_t flutter_mxlogger_log(void *handle, const char *name, int32_t level, const char *msg, const char *tag) {
    return safe<int32_t>(-4, [&] { Access access(handle); return write(access, level, name, msg, tag); });
}
int32_t flutter_mxlogger_log_loggerToken(const char *token, const char *name, int32_t level, const char *msg, const char *tag) {
    return safe<int32_t>(-4, [&] { Access access(registry().by_token(token)); return write(access, level, name, msg, tag); });
}
int32_t mxlogger_ohos_configure(void *handle, int32_t option, int64_t value) {
    return safe<int32_t>(-1, [&] {
        Access access(handle);
        require(value >= 0 && value <= 9007199254740991LL, "configuration must be a nonnegative safe integer");
        switch (option) {
            case 0: require(value <= 4, "level must be 0..4"); access->set_log_level(static_cast<int>(value)); break;
            case 1: require(value <= 1, "enable must be boolean"); access->set_enable(value != 0); break;
            case 2: require(value <= 1, "console must be boolean"); access.session->console = value != 0; break;
            case 3: require(value <= LONG_MAX, "maxDiskAge exceeds native range"); access->set_file_max_age(static_cast<long>(value)); break;
            case 4: require(value <= LONG_MAX, "maxDiskSize exceeds native range"); access->set_file_max_size(static_cast<long>(value)); break;
            default: throw Error(1, "unknown configuration option");
        }
        return 0;
    });
}
void flutter_mxlogger_set_enable(void *h, int32_t v) { mxlogger_ohos_configure(h, 1, v); }
void flutter_mxlogger_set_console_enable(void *h, int32_t v) { mxlogger_ohos_configure(h, 2, v); }
void flutter_mxlogger_set_level(void *h, int32_t v) { mxlogger_ohos_configure(h, 0, v); }
void flutter_mxlogger_set_max_disk_age(void *h, int32_t v) { mxlogger_ohos_configure(h, 3, v); }
void flutter_mxlogger_set_max_disk_size(void *h, int32_t v) { mxlogger_ohos_configure(h, 4, v); }
int32_t flutter_mxlogger_get_log_size(void *h) {
    return safe<int32_t>(0, [&] { Access access(h); return static_cast<int32_t>(std::clamp<long>(access->dir_size(), 0, INT32_MAX)); });
}
char *flutter_mxlogger_get_loggerToken(void *h) { return safe<char *>(nullptr, [&] { Access a(h); return copy(a->logger_token()); }); }
char *flutter_mxlogger_get_diskcache_path(void *h) { return safe<char *>(nullptr, [&] { Access a(h); return copy(a->diskcache_path()); }); }
char *flutter_mxlogger_get_error_desc(void *h) { return safe<char *>(nullptr, [&] { Access a(h); return copy(a->error_desc()); }); }
void flutter_mxlogger_free_string(char *s) { free(s); }
void flutter_mxlogger_remove_before_all_data(void *h) { safe<int>(0, [&] { Access a(h); a->remove_before_all(); return 1; }); }
void flutter_mxlogger_remove_expire_data(void *h) { safe<int>(0, [&] { Access a(h); a->remove_expire_data(); return 1; }); }
void flutter_mxlogger_remove_all(void *h) { safe<int>(0, [&] { Access a(h); a->remove_all(); return 1; }); }

char *mxlogger_ohos_snapshot(void *h) {
    return safe<char *>(nullptr, [&] {
        Access a(h);
        Json state(cJSON_CreateObject(), cJSON_Delete);
        cJSON_AddStringToObject(state.get(), "loggerToken", a->logger_token());
        cJSON_AddStringToObject(state.get(), "diskCachePath", a->diskcache_path());
        cJSON_AddStringToObject(state.get(), "errorDesc", a->error_desc());
        cJSON_AddNumberToObject(state.get(), "level", a->log_level());
        cJSON_AddBoolToObject(state.get(), "enable", a->is_enable());
        cJSON_AddBoolToObject(state.get(), "consoleEnable", a.session->console);
        cJSON_AddNumberToObject(state.get(), "maxDiskAge", static_cast<double>(a->file_max_age()));
        cJSON_AddNumberToObject(state.get(), "maxDiskSize", static_cast<double>(a->file_max_size()));
        cJSON_AddNumberToObject(state.get(), "logSize", static_cast<double>(a->dir_size()));
        return serialize(state.get());
    });
}
char *mxlogger_ohos_files(void *h) {
    return safe<char *>(nullptr, [&] { Access a(h); auto value = rows_json(files(a.session->core)); return serialize(value.get()); });
}
char *mxlogger_ohos_read_file(void *h, const char *filename) {
    return safe<char *>(nullptr, [&] {
        component(text(filename));
        Access a(h);
        const auto &cfg = a.session->config;
        auto rows = records((std::string(a->diskcache_path()) + filename).c_str(),
            cfg[3].empty() ? nullptr : cfg[3].c_str(), cfg[4].empty() ? nullptr : cfg[4].c_str());
        for (const auto &row : rows) if (row.at("error_code") != "0") throw Error(4, "log decode failed");
        auto value = rows_json(rows);
        return serialize(value.get());
    });
}
void flutter_mxlogger_free_logfiles(int32_t count, char ***rows, uint32_t **lengths) {
    mxlogger_ffi_detail::free_files(count, rows, lengths);
}
int32_t flutter_mxlogger_get_logfiles(void *h, char ****output, uint32_t ***lengths) {
    if (!output || !lengths) return 0;
    *output = nullptr; *lengths = nullptr;
    return safe<int32_t>(0, [&] {
        Access a(h); const auto rows = files(a.session->core);
        if (rows.size() > INT32_MAX) throw Error(4, "too many files");
        const auto count = static_cast<int32_t>(rows.size());
        if (!count) return count;
        if (!mxlogger_ffi_detail::allocate_files(count, output, lengths)) {
            flutter_mxlogger_free_logfiles(count, *output, *lengths); *output = nullptr; *lengths = nullptr;
            throw std::bad_alloc();
        }
        const char *fields[] = {"name", "size", "last_timestamp", "create_timestamp"};
        for (int i = 0; i < count; ++i) for (int j = 0; j < 4; ++j) {
            if (!mxlogger_ffi_detail::set_file_field((*output)[i], (*lengths)[i], j, rows[i].at(fields[j]).c_str())) {
                flutter_mxlogger_free_logfiles(count, *output, *lengths); *output = nullptr; *lengths = nullptr;
                throw std::bad_alloc();
            }
        }
        return count;
    });
}
void flutter_mxlogger_free_logmsg(int32_t count, char **rows, uint32_t *lengths) {
    for (int32_t i = 0; i < count; ++i) if (rows) free(rows[i]);
    free(rows); free(lengths);
}
int32_t flutter_mxlogger_select_logmsg(const char *path, const char *key, const char *iv,
    int32_t *count, char ***output, uint32_t **lengths) {
    if (!count || !output || !lengths) return -1;
    *count = 0; *output = nullptr; *lengths = nullptr;
    return safe<int32_t>(-1, [&] {
        const auto rows = records(path, key, iv);
        if (rows.size() > INT32_MAX) throw Error(4, "too many records");
        const auto size = static_cast<int32_t>(rows.size());
        if (!size) return 0;
        *output = static_cast<char **>(calloc(size, sizeof(char *)));
        *lengths = static_cast<uint32_t *>(calloc(size, sizeof(uint32_t)));
        try {
            if (!*output || !*lengths) throw std::bad_alloc();
            for (int i = 0; i < size; ++i) {
                Json item(cJSON_CreateObject(), cJSON_Delete);
                for (const auto &field : rows[size - 1 - i])
                    cJSON_AddStringToObject(item.get(), field.first.c_str(), field.second.c_str());
                (*output)[i] = serialize(item.get());
                (*lengths)[i] = static_cast<uint32_t>(strlen((*output)[i]));
            }
        } catch (...) {
            flutter_mxlogger_free_logmsg(size, *output, *lengths); *output = nullptr; *lengths = nullptr;
            throw;
        }
        *count = size;
        return 0;
    });
}
uint32_t flutter_mxlogger_select_logfiles(const char *, char ***output, uint32_t **lengths) {
    if (output) *output = nullptr;
    if (lengths) *lengths = nullptr;
    return 0;
}
