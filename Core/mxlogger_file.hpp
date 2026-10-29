#ifndef MXLOGGER_FILE_HPP
#define MXLOGGER_FILE_HPP

#include "mxlogger_platform.hpp"
#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <string>
#include <system_error>
#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#if MXLOGGER_MULTIPROCESS
#include <sys/file.h>
#endif
#endif

namespace mxlogger {
namespace files {

inline std::error_code system_error() {
#ifdef _WIN32
    return {static_cast<int>(GetLastError()), std::system_category()};
#else
    return {errno, std::generic_category()};
#endif
}

inline bool is_missing(const std::error_code &error) {
#ifdef _WIN32
    return error.value() == ERROR_FILE_NOT_FOUND || error.value() == ERROR_PATH_NOT_FOUND;
#else
    return error.value() == ENOENT;
#endif
}

#ifdef _WIN32
inline uint64_t file_time_now() {
    FILETIME value{};
    GetSystemTimeAsFileTime(&value);
    return (uint64_t(value.dwHighDateTime) << 32) | value.dwLowDateTime;
}
inline std::wstring to_wide(const char *utf8) {
    if (!utf8) return {};
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, nullptr, 0);
    if (count <= 1) return {};
    std::wstring result(static_cast<size_t>(count), L'\0');
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8, -1, &result[0], count)) return {};
    result.pop_back();
    return result;
}

inline std::string to_utf8(const wchar_t *wide) {
    if (!wide) return {};
    int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, nullptr, 0, nullptr, nullptr);
    if (count <= 1) return {};
    std::string result(static_cast<size_t>(count), '\0');
    if (!WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, &result[0], count, nullptr, nullptr)) return {};
    result.pop_back();
    return result;
}
#endif

inline std::string error_message(const std::error_code &error) {
#ifdef _WIN32
    if (error.category() == std::system_category()) {
        wchar_t buffer[1024]{};
        if (FormatMessageW(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, nullptr,
                           static_cast<DWORD>(error.value()), 0, buffer, 1024, nullptr)) {
            return to_utf8(buffer);
        }
        return "Windows error " + std::to_string(error.value());
    }
#endif
    return error.message();
}

struct file_info {
    uint64_t size = 0;
    uint64_t volume = 0;
    uint64_t index = 0;
    bool same_file(const file_info &other) const {
        return volume == other.volume && index == other.index;
    }
};

// Owns an OS file handle. Mapping, process coordination and live-file leases
// have separate lifetimes; closing a data handle must not release those leases.
class native_file {
public:
#ifdef _WIN32
    using handle_type = HANDLE;
#else
    using handle_type = int;
#endif
    native_file() = default;
    ~native_file() { close(); }
    native_file(const native_file &) = delete;
    native_file &operator=(const native_file &) = delete;

    bool valid() const {
#ifdef _WIN32
        return handle_ != INVALID_HANDLE_VALUE;
#else
        return handle_ >= 0;
#endif
    }
    handle_type get() const { return handle_; }
    const std::error_code &error() const { return error_; }
    std::string error_message() const { return files::error_message(error_); }

    bool open(const std::string &path, bool read_only = false, bool create = false,
              bool share_delete = true) {
        if (!close()) return false;
#ifdef _WIN32
        const auto wide = to_wide(path.c_str());
        if (wide.empty()) { error_ = std::make_error_code(std::errc::invalid_argument); return false; }
        handle_ = CreateFileW(wide.c_str(), read_only ? GENERIC_READ : GENERIC_READ | GENERIC_WRITE,
                              FILE_SHARE_READ | FILE_SHARE_WRITE | (share_delete ? FILE_SHARE_DELETE : 0),
                              nullptr, create ? OPEN_ALWAYS : OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
#else
        int flags = (read_only ? O_RDONLY : O_RDWR) | O_CLOEXEC | (create ? O_CREAT : 0);
        const auto mode = share_delete ? S_IRWXU : S_IRUSR | S_IWUSR;
        do { handle_ = ::open(path.c_str(), flags, mode); } while (handle_ < 0 && errno == EINTR);
#endif
        return record(valid());
    }

    bool close() {
        if (!valid()) return true;
#ifdef _WIN32
        if (!CloseHandle(handle_)) return record(false);
        handle_ = INVALID_HANDLE_VALUE;
#else
        // Do not retry close after EINTR: the descriptor may already be reused.
        int fd = handle_;
        handle_ = -1;
        if (::close(fd) != 0) return record(false);
#endif
        return true;
    }

    bool info(file_info &result) {
#ifdef _WIN32
        BY_HANDLE_FILE_INFORMATION value{};
        if (!GetFileInformationByHandle(handle_, &value)) return record(false);
        result.size = (uint64_t(value.nFileSizeHigh) << 32) | value.nFileSizeLow;
        result.volume = value.dwVolumeSerialNumber;
        result.index = (uint64_t(value.nFileIndexHigh) << 32) | value.nFileIndexLow;
#else
        struct stat value{};
        if (::fstat(handle_, &value) != 0) return record(false);
        result.size = static_cast<uint64_t>(value.st_size);
        result.volume = static_cast<uint64_t>(value.st_dev);
        result.index = static_cast<uint64_t>(value.st_ino);
#endif
        return record(true);
    }

    bool resize(size_t size) {
#ifdef _WIN32
        LARGE_INTEGER position{};
        position.QuadPart = static_cast<LONGLONG>(size);
        return record(SetFilePointerEx(handle_, position, nullptr, FILE_BEGIN) && SetEndOfFile(handle_));
#else
        return record(::ftruncate(handle_, static_cast<off_t>(size)) == 0);
#endif
    }

#ifdef _WIN32
    bool update_write_time(uint64_t ticks) {
        const FILETIME value{static_cast<DWORD>(ticks), static_cast<DWORD>(ticks >> 32)};
        return record(SetFileTime(handle_, nullptr, nullptr, &value) != 0);
    }
#endif

    std::ptrdiff_t read(void *buffer, size_t size) {
        size = std::min<size_t>(size, std::numeric_limits<int>::max());
#ifdef _WIN32
        DWORD count = 0;
        if (!ReadFile(handle_, buffer, static_cast<DWORD>(size), &count, nullptr)) { record(false); return -1; }
        return static_cast<std::ptrdiff_t>(count);
#else
        ssize_t count;
        do { count = ::read(handle_, buffer, size); } while (count < 0 && errno == EINTR);
        if (count < 0) record(false);
        return count;
#endif
    }

    std::ptrdiff_t read_at(void *buffer, size_t size, uint64_t offset) {
        if (!seek(offset)) return -1;
        return read(buffer, size);
    }

    std::ptrdiff_t write_at(const void *buffer, size_t size, uint64_t offset) {
        if (!seek(offset)) return -1;
#ifdef _WIN32
        DWORD count = 0;
        if (!WriteFile(handle_, buffer, static_cast<DWORD>(std::min<size_t>(size, INT_MAX)), &count, nullptr)) {
            record(false); return -1;
        }
        return static_cast<std::ptrdiff_t>(count);
#else
        ssize_t count;
        do { count = ::write(handle_, buffer, size); } while (count < 0 && errno == EINTR);
        if (count < 0) record(false);
        return count;
#endif
    }

#if MXLOGGER_MULTIPROCESS
    bool lock(bool exclusive, bool wait = true, uint64_t offset = 0) {
#ifdef _WIN32
        OVERLAPPED position{};
        position.Offset = static_cast<DWORD>(offset);
        position.OffsetHigh = static_cast<DWORD>(offset >> 32);
        DWORD flags = (exclusive ? LOCKFILE_EXCLUSIVE_LOCK : 0) | (wait ? 0 : LOCKFILE_FAIL_IMMEDIATELY);
        return record(LockFileEx(handle_, flags, 0, 1, 0, &position) != 0);
#else
        (void)offset;
        int result;
        do { result = ::flock(handle_, (exclusive ? LOCK_EX : LOCK_SH) | (wait ? 0 : LOCK_NB)); }
        while (result != 0 && errno == EINTR);
        return record(result == 0);
#endif
    }

    bool unlock(uint64_t offset = 0) {
#ifdef _WIN32
        OVERLAPPED position{};
        position.Offset = static_cast<DWORD>(offset);
        position.OffsetHigh = static_cast<DWORD>(offset >> 32);
        return record(UnlockFileEx(handle_, 0, 1, 0, &position) != 0);
#else
        (void)offset;
        int result;
        do { result = ::flock(handle_, LOCK_UN); } while (result != 0 && errno == EINTR);
        return record(result == 0);
#endif
    }
#endif

private:
    bool record(bool success) { error_ = success ? std::error_code{} : system_error(); return success; }
    bool seek(uint64_t offset) {
#ifdef _WIN32
        LARGE_INTEGER position{};
        position.QuadPart = static_cast<LONGLONG>(offset);
        return record(SetFilePointerEx(handle_, position, nullptr, FILE_BEGIN) != 0);
#else
        return record(::lseek(handle_, static_cast<off_t>(offset), SEEK_SET) >= 0);
#endif
    }
#ifdef _WIN32
    handle_type handle_ = INVALID_HANDLE_VALUE;
#else
    handle_type handle_ = -1;
#endif
    std::error_code error_;
};

inline bool path_info(const std::string &path, file_info &info, std::error_code &error) {
#ifdef _WIN32
    native_file file;
    const bool success = file.open(path, true) && file.info(info);
    error = file.error();
    return success;
#else
    struct stat value{};
    if (::stat(path.c_str(), &value) != 0) { error = system_error(); return false; }
    info.size = static_cast<uint64_t>(value.st_size);
    info.volume = static_cast<uint64_t>(value.st_dev);
    info.index = static_cast<uint64_t>(value.st_ino);
    error.clear();
    return true;
#endif
}

class mapped_view {
public:
    mapped_view() = default;
    ~mapped_view() { unmap(); }
    mapped_view(const mapped_view &) = delete;
    mapped_view &operator=(const mapped_view &) = delete;
    uint8_t *data() const { return data_; }
    const std::error_code &error() const { return error_; }
    std::string error_message() const { return files::error_message(error_); }

    bool map(native_file &file, size_t size, bool writable = true) {
        if (!unmap()) return false;
        if (!size || !file.valid()) { error_ = std::make_error_code(std::errc::invalid_argument); return false; }
#ifdef _WIN32
        object_ = CreateFileMappingW(file.get(), nullptr, writable ? PAGE_READWRITE : PAGE_READONLY, 0, 0, nullptr);
        if (!object_) { error_ = system_error(); return false; }
        data_ = static_cast<uint8_t *>(MapViewOfFile(object_, writable ? FILE_MAP_ALL_ACCESS : FILE_MAP_READ, 0, 0, size));
        if (!data_) {
            error_ = system_error();
            CloseHandle(object_);
            object_ = nullptr;
            return false;
        }
#else
        void *value = ::mmap(nullptr, size, writable ? PROT_READ | PROT_WRITE : PROT_READ, MAP_SHARED, file.get(), 0);
        if (value == MAP_FAILED) { error_ = system_error(); return false; }
        data_ = static_cast<uint8_t *>(value);
#endif
        size_ = size;
        error_.clear();
        return true;
    }

    bool unmap() {
        if (data_) {
#ifdef _WIN32
            if (!UnmapViewOfFile(data_)) { error_ = system_error(); return false; }
#else
            if (::munmap(data_, size_) != 0) { error_ = system_error(); return false; }
#endif
            data_ = nullptr;
            size_ = 0;
        }
#ifdef _WIN32
        if (object_) {
            if (!CloseHandle(object_)) { error_ = system_error(); return false; }
            object_ = nullptr;
        }
#endif
        return true;
    }

private:
    uint8_t *data_ = nullptr;
    size_t size_ = 0;
    std::error_code error_;
#ifdef _WIN32
    HANDLE object_ = nullptr;
#endif
};

} // namespace files
} // namespace mxlogger
#endif
