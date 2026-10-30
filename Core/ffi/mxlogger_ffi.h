#ifndef MXLOGGER_FFI_H
#define MXLOGGER_FFI_H

#include <stdint.h>

#if defined(_WIN32)
#if defined(MXLOGGER_FFI_BUILD)
#define MXLOGGER_FFI_API __declspec(dllexport)
#else
#define MXLOGGER_FFI_API __declspec(dllimport)
#endif
#define MXLOGGER_FFI_CALL __cdecl
#else
#define MXLOGGER_FFI_API __attribute__((visibility("default")))
#define MXLOGGER_FFI_CALL
#endif

#ifdef __cplusplus
extern "C" {
#endif

// C ABI shared by Dart bindings. Handles are pointers, never fixed-width integers.
// UTF-8 inputs are borrowed for the call. Returned heap memory belongs to the
// allocating module and MUST use its paired free function, including on Windows.
MXLOGGER_FFI_API const char* MXLOGGER_FFI_CALL flutter_mxlogger_core_version(void); // borrowed
MXLOGGER_FFI_API void* MXLOGGER_FFI_CALL flutter_mxlogger_initialize(
    const char* ns, const char* directory, const char* policy, const char* file_name,
    const char* file_header, const char* crypt_key, const char* iv);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_destroy(const char* ns, const char* directory);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_destroyWithLoggerToken(const char* token);
MXLOGGER_FFI_API int32_t MXLOGGER_FFI_CALL flutter_mxlogger_log(void* handle, const char* name, int32_t level, const char* msg, const char* tag);
MXLOGGER_FFI_API int32_t MXLOGGER_FFI_CALL flutter_mxlogger_log_loggerToken(const char* token, const char* name, int32_t level, const char* msg, const char* tag);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_set_enable(void* handle, int32_t enabled);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_set_console_enable(void* handle, int32_t enabled);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_set_level(void* handle, int32_t level);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_set_max_disk_age(void* handle, int32_t seconds);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_set_max_disk_size(void* handle, int32_t bytes);
MXLOGGER_FFI_API int32_t MXLOGGER_FFI_CALL flutter_mxlogger_get_log_size(void* handle); // saturates at INT32_MAX
MXLOGGER_FFI_API char* MXLOGGER_FFI_CALL flutter_mxlogger_get_loggerToken(void* handle);
MXLOGGER_FFI_API char* MXLOGGER_FFI_CALL flutter_mxlogger_get_diskcache_path(void* handle);
MXLOGGER_FFI_API char* MXLOGGER_FFI_CALL flutter_mxlogger_get_error_desc(void* handle);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_free_string(char* string);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_remove_before_all_data(void* handle);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_remove_expire_data(void* handle);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_remove_all(void* handle);

// Fields per row: name, size, last_timestamp, create_timestamp. Lengths are byte
// counts, excluding the terminating NUL. Output pointers are NULL on empty/error.
MXLOGGER_FFI_API int32_t MXLOGGER_FFI_CALL flutter_mxlogger_get_logfiles(void* handle, char**** rows, uint32_t*** lengths);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_free_logfiles(int32_t count, char*** rows, uint32_t** lengths);
MXLOGGER_FFI_API int32_t MXLOGGER_FFI_CALL flutter_mxlogger_select_logmsg(const char* path, const char* key, const char* iv, int32_t* count, char*** rows, uint32_t** lengths);
MXLOGGER_FFI_API void MXLOGGER_FFI_CALL flutter_mxlogger_free_logmsg(int32_t count, char** rows, uint32_t* lengths);
// Legacy placeholder, retained for ABI compatibility; use get_logfiles instead.
MXLOGGER_FFI_API uint32_t MXLOGGER_FFI_CALL flutter_mxlogger_select_logfiles(const char* directory, char*** rows, uint32_t** lengths);

#if defined(_WIN32)
// %LOCALAPPDATA%/MXLogger/<executable stem>; free using free_string.
MXLOGGER_FFI_API char* MXLOGGER_FFI_CALL flutter_mxlogger_default_directory(void);
#endif

#ifdef __cplusplus
}
#endif
#endif
