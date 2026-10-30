// Pure C++ bridge shared by Android and Windows. No JNI or Flutter engine API.
#include "mxlogger_ffi.h"
#include "mxlogger_ffi_memory.hpp"
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
#include "json/cJSON.h"
#include <limits.h>
#include <memory>

using mxlogger::util::mxlogger_util;

const char* MXLOGGER_FFI_CALL flutter_mxlogger_core_version() { return mx_logger::version(); }

void* MXLOGGER_FFI_CALL flutter_mxlogger_initialize(const char* ns, const char* directory, const char* policy,
    const char* file_name, const char* file_header, const char* key, const char* iv) {
    if (!ns || !directory) return nullptr;
    try {
        auto* logger = mx_logger::initialize_namespace(ns, directory, policy, file_name, file_header, key, iv);
        if (logger) logger->set_enable_console(false);
        return logger;
    } catch (...) { return nullptr; }
}

void MXLOGGER_FFI_CALL flutter_mxlogger_destroy(const char* ns, const char* directory) { mx_logger::delete_namespace(ns, directory); }
void MXLOGGER_FFI_CALL flutter_mxlogger_destroyWithLoggerToken(const char* token) { mx_logger::delete_namespace(token); }
void MXLOGGER_FFI_CALL flutter_mxlogger_set_enable(void* handle, int32_t value) { if (handle) static_cast<mx_logger*>(handle)->set_enable(value != 0); }
void MXLOGGER_FFI_CALL flutter_mxlogger_set_console_enable(void* handle, int32_t value) { if (handle) static_cast<mx_logger*>(handle)->set_enable_console(value != 0); }
void MXLOGGER_FFI_CALL flutter_mxlogger_set_level(void* handle, int32_t value) { if (handle) static_cast<mx_logger*>(handle)->set_log_level(value); }
void MXLOGGER_FFI_CALL flutter_mxlogger_set_max_disk_age(void* handle, int32_t value) { if (handle) static_cast<mx_logger*>(handle)->set_file_max_age(value); }
void MXLOGGER_FFI_CALL flutter_mxlogger_set_max_disk_size(void* handle, int32_t value) { if (handle) static_cast<mx_logger*>(handle)->set_file_max_size(value); }
int32_t MXLOGGER_FFI_CALL flutter_mxlogger_get_log_size(void* handle) {
    if (!handle) return 0;
    const auto size = static_cast<mx_logger*>(handle)->dir_size();
    return size <= 0 ? 0 : size > INT32_MAX ? INT32_MAX : static_cast<int32_t>(size);
}
char* MXLOGGER_FFI_CALL flutter_mxlogger_get_loggerToken(void* handle) { return handle ? mxlogger_ffi_detail::copy_string(static_cast<mx_logger*>(handle)->logger_token()) : nullptr; }
char* MXLOGGER_FFI_CALL flutter_mxlogger_get_diskcache_path(void* handle) { return handle ? mxlogger_ffi_detail::copy_string(static_cast<mx_logger*>(handle)->diskcache_path()) : nullptr; }
char* MXLOGGER_FFI_CALL flutter_mxlogger_get_error_desc(void* handle) { return handle ? mxlogger_ffi_detail::copy_string(static_cast<mx_logger*>(handle)->error_desc()) : nullptr; }
void MXLOGGER_FFI_CALL flutter_mxlogger_free_string(char* string) { free(string); }
void MXLOGGER_FFI_CALL flutter_mxlogger_remove_before_all_data(void* handle) { if (handle) static_cast<mx_logger*>(handle)->remove_before_all(); }
void MXLOGGER_FFI_CALL flutter_mxlogger_remove_expire_data(void* handle) { if (handle) static_cast<mx_logger*>(handle)->remove_expire_data(); }
void MXLOGGER_FFI_CALL flutter_mxlogger_remove_all(void* handle) { if (handle) static_cast<mx_logger*>(handle)->remove_all(); }
int32_t MXLOGGER_FFI_CALL flutter_mxlogger_log(void* handle, const char* name, int32_t level, const char* msg, const char* tag) {
    return handle ? static_cast<mx_logger*>(handle)->log(level, name, msg, tag, true) : -4;
}
int32_t MXLOGGER_FFI_CALL flutter_mxlogger_log_loggerToken(const char* token, const char* name, int32_t level, const char* msg, const char* tag) {
    auto* logger = mx_logger::global_for_loggerToken(token);
    return logger ? logger->log(level, name, msg, tag, true) : 0;
}

void MXLOGGER_FFI_CALL flutter_mxlogger_free_logfiles(int32_t count, char*** rows, uint32_t** lengths) {
    mxlogger_ffi_detail::free_files(count, rows, lengths);
}

int32_t MXLOGGER_FFI_CALL flutter_mxlogger_get_logfiles(void* handle, char**** output, uint32_t*** sizes) {
    if (!output || !sizes) return 0;
    *output = nullptr; *sizes = nullptr;
    if (!handle) return 0;
    char*** rows = nullptr;
    uint32_t** lengths = nullptr;
    int32_t count = 0;
    try {
        std::vector<std::map<std::string, std::string>> files;
        mxlogger_util::select_logfiles_dir(static_cast<mx_logger*>(handle)->diskcache_path(), &files);
        if (files.empty() || files.size() > INT32_MAX) return 0;
        count = static_cast<int32_t>(files.size());
        if (!mxlogger_ffi_detail::allocate_files(count, &rows, &lengths)) {
            flutter_mxlogger_free_logfiles(count, rows, lengths); return 0;
        }
        const char* keys[] = {"name", "size", "last_timestamp", "create_timestamp"};
        for (int32_t i = 0; i < count; ++i) {
            for (int32_t field = 0; field < 4; ++field) {
                if (!mxlogger_ffi_detail::set_file_field(rows[i], lengths[i], field, files[i].at(keys[field]).c_str())) {
                    flutter_mxlogger_free_logfiles(count, rows, lengths); return 0;
                }
            }
        }
        *output = rows; *sizes = lengths;
        return count;
    } catch (...) { flutter_mxlogger_free_logfiles(count, rows, lengths); return 0; }
}

void MXLOGGER_FFI_CALL flutter_mxlogger_free_logmsg(int32_t count, char** rows, uint32_t* lengths) {
    if (rows) { for (int32_t i = 0; i < count; ++i) free(rows[i]); free(rows); }
    free(lengths);
}

int32_t MXLOGGER_FFI_CALL flutter_mxlogger_select_logmsg(const char* path, const char* key, const char* iv,
    int32_t* number, char*** output, uint32_t** sizes) {
    if (!number || !output || !sizes) return -1;
    *number = 0; *output = nullptr; *sizes = nullptr;
    if (!path) return -1;
    char** rows = nullptr;
    uint32_t* lengths = nullptr;
    int32_t count = 0;
    try {
        std::vector<std::map<std::string, std::string>> records;
        mxlogger_util::select_log_form_path(path, &records, key, iv);
        if (records.empty()) return 0;
        if (records.size() > INT32_MAX) return -1;
        count = static_cast<int32_t>(records.size());
        rows = static_cast<char**>(calloc(static_cast<size_t>(count), sizeof(char*)));
        lengths = static_cast<uint32_t*>(calloc(static_cast<size_t>(count), sizeof(uint32_t)));
        if (!rows || !lengths) { flutter_mxlogger_free_logmsg(count, rows, lengths); return -1; }
        for (int32_t i = 0; i < count; ++i) {
            std::unique_ptr<cJSON, decltype(&cJSON_Delete)> item(cJSON_CreateObject(), &cJSON_Delete);
            if (!item) { flutter_mxlogger_free_logmsg(count, rows, lengths); return -1; }
            for (const auto& entry : records[count - 1 - i]) {
                if (!cJSON_AddStringToObject(item.get(), entry.first.c_str(), entry.second.c_str())) {
                    flutter_mxlogger_free_logmsg(count, rows, lengths); return -1;
                }
            }
            rows[i] = cJSON_PrintUnformatted(item.get());
            if (!rows[i]) { flutter_mxlogger_free_logmsg(count, rows, lengths); return -1; }
            const size_t length = strlen(rows[i]);
            if (length > UINT32_MAX) { flutter_mxlogger_free_logmsg(count, rows, lengths); return -1; }
            lengths[i] = static_cast<uint32_t>(length);
        }
        *output = rows; *sizes = lengths; *number = count;
        return 0;
    } catch (...) { flutter_mxlogger_free_logmsg(count, rows, lengths); return -1; }
}

uint32_t MXLOGGER_FFI_CALL flutter_mxlogger_select_logfiles(const char*, char*** rows, uint32_t** lengths) {
    if (rows) *rows = nullptr;
    if (lengths) *lengths = nullptr;
    return 0;
}
