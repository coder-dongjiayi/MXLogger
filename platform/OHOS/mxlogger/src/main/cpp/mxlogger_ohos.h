#pragma once
#include "mxlogger_ffi.h"

// OHOS handles are opaque, independently owned wrappers over a shared session.
// destroy invalidates the session and all its wrappers; release only frees this
// wrapper. After release, callers must discard that pointer permanently.
#ifdef __cplusplus
extern "C" {
#endif
MXLOGGER_FFI_API const char *mxlogger_ohos_last_error(void);
MXLOGGER_FFI_API int32_t mxlogger_ohos_last_error_code(void);
MXLOGGER_FFI_API void flutter_mxlogger_release_handle(void *handle);
MXLOGGER_FFI_API void mxlogger_ohos_destroy_handle(void *handle);
MXLOGGER_FFI_API int32_t mxlogger_ohos_is_valid(void *handle);
MXLOGGER_FFI_API int32_t mxlogger_ohos_flush(void *handle);
// 0:level, 1:enable, 2:console, 3:maxDiskAge, 4:maxDiskSize.
MXLOGGER_FFI_API int32_t mxlogger_ohos_configure(void *handle, int32_t option, int64_t value);
// All returned strings use flutter_mxlogger_free_string.
MXLOGGER_FFI_API char *mxlogger_ohos_snapshot(void *handle);
MXLOGGER_FFI_API char *mxlogger_ohos_files(void *handle);
MXLOGGER_FFI_API char *mxlogger_ohos_read_file(void *handle, const char *filename);
// Acquire another owned wrapper for the current live token, or fail.
MXLOGGER_FFI_API void *mxlogger_ohos_attach(const char *token);
#ifdef __cplusplus
}
#endif
