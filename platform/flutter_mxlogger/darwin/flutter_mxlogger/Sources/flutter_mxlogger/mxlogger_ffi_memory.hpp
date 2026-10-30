#ifndef MXLOGGER_FFI_MEMORY_HPP
#define MXLOGGER_FFI_MEMORY_HPP
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

namespace mxlogger_ffi_detail {
inline char* copy_string(const char* value) {
    if (!value) return nullptr;
    const size_t length = strlen(value);
    char* result = static_cast<char*>(malloc(length + 1));
    if (result) memcpy(result, value, length + 1);
    return result;
}

inline void free_files(int32_t count, char*** rows, uint32_t** lengths) {
    for (int32_t i = 0; i < count; ++i) {
        if (rows && rows[i]) {
            for (int32_t field = 0; field < 4; ++field) free(rows[i][field]);
            free(rows[i]);
        }
        if (lengths) free(lengths[i]);
    }
    free(rows);
    free(lengths);
}

inline bool allocate_files(int32_t count, char**** rows, uint32_t*** lengths) {
    *rows = static_cast<char***>(calloc(static_cast<size_t>(count), sizeof(char**)));
    *lengths = static_cast<uint32_t**>(calloc(static_cast<size_t>(count), sizeof(uint32_t*)));
    if (!*rows || !*lengths) return false;
    for (int32_t i = 0; i < count; ++i) {
        (*rows)[i] = static_cast<char**>(calloc(4, sizeof(char*)));
        (*lengths)[i] = static_cast<uint32_t*>(calloc(4, sizeof(uint32_t)));
        if (!(*rows)[i] || !(*lengths)[i]) return false;
    }
    return true;
}

inline bool set_file_field(char** row, uint32_t* lengths, int32_t field, const char* value) {
    if (!value) value = "";
    const size_t length = strlen(value);
    if (length > UINT32_MAX) return false;
    row[field] = copy_string(value);
    if (!row[field]) return false;
    lengths[field] = static_cast<uint32_t>(length);
    return true;
}
}
#endif
