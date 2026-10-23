#ifndef mxlogger_interprocess_hpp
#define mxlogger_interprocess_hpp

#if defined(__APPLE__)
#include <TargetConditionals.h>
#endif

// Native macOS only. iOS (including Catalyst), Android and Windows keep their
// existing paths. A future Windows backend must implement the same protocol.
#if defined(__APPLE__) && TARGET_OS_OSX
#define MXLOGGER_MACOS_MULTIPROCESS 1
#else
#define MXLOGGER_MACOS_MULTIPROCESS 0
#endif

#if MXLOGGER_MACOS_MULTIPROCESS
#include <cerrno>
#include <fcntl.h>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <new>
#include <string>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

namespace mxlogger {
namespace ipc {

constexpr const char *lock_filename = ".mxlogger.lock";

inline bool flock_retry(int fd, int operation) {
    int result;
    do {
        result = ::flock(fd, operation);
    } while (result != 0 && errno == EINTR);
    return result == 0;
}

inline std::string parent_directory(const std::string &path) {
    auto slash = path.find_last_of('/');
    return slash == std::string::npos ? "./" : path.substr(0, slash + 1);
}

// One persistent coordination file per logger directory. Never unlink this file:
// all cooperating writers, readers and cleaners must lock the same inode.
// A sink reuses its fd under the existing C++ logger_mutex. Standalone reads use
// separate fds, so a shared lock cannot downgrade a writer's exclusive lock.
class directory_lock {
public:
    explicit directory_lock(const std::string &directory, bool create = true)
        : path_((directory.empty() ? "." : directory) +
                (directory.empty() || directory.back() != '/' ? "/" : "") + lock_filename),
          create_(create) {}
    ~directory_lock() { if (fd_ >= 0) ::close(fd_); }

    bool lock(bool exclusive) {
        if (fd_ < 0) {
            do {
                fd_ = ::open(path_.c_str(), (create_ ? O_RDWR | O_CREAT : O_RDONLY) | O_CLOEXEC, 0600);
            } while (fd_ < 0 && errno == EINTR);
            // Legacy/exported files have no coordinator. Reading them must not
            // create files or require write permission in the source directory.
            if (fd_ < 0) return !create_ && errno == ENOENT;
        }
        return flock_retry(fd_, exclusive ? LOCK_EX : LOCK_SH);
    }
    void unlock() { if (fd_ >= 0) flock_retry(fd_, LOCK_UN); }

    directory_lock(const directory_lock &) = delete;
    directory_lock &operator=(const directory_lock &) = delete;

private:
    std::string path_;
    bool create_;
    int fd_ = -1;
};

class scoped_lock {
public:
    explicit scoped_lock(directory_lock &lock, bool exclusive = true)
        : lock_(lock), locked_(lock.lock(exclusive)) {}
    ~scoped_lock() { if (locked_) lock_.unlock(); }
    explicit operator bool() const { return locked_; }
    scoped_lock(const scoped_lock &) = delete;
    scoped_lock &operator=(const scoped_lock &) = delete;
private:
    directory_lock &lock_;
    bool locked_;
};

// Called while holding the directory's exclusive lock. Writers keep a shared
// lock on the data fd for their lifetime; an exclusive nonblocking probe detects
// live writers without PID files or stale process registrations.
inline bool file_is_inactive(const std::string &path) {
    int fd = ::open(path.c_str(), O_RDONLY | O_CLOEXEC);
    if (fd < 0) return false;
    bool inactive = flock_retry(fd, LOCK_EX | LOCK_NB);
    ::close(fd);
    return inactive;
}

// Copy only committed bytes while holding the shared lock. Decryption and
// FlatBuffers decoding then run outside the lock, without blocking writers.
inline bool read_snapshot(const char *path, std::vector<uint8_t> &snapshot) {
    directory_lock directory_lock(parent_directory(path), false);
    scoped_lock lock(directory_lock, false);
    if (!lock) return false;
    int fd = ::open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return false;
    struct stat info{};
    uint32_t committed = 0;
    ssize_t result;
    do { result = ::read(fd, &committed, sizeof(committed)); } while (result < 0 && errno == EINTR);
    if (::fstat(fd, &info) != 0 || info.st_size < 4 || result != sizeof(committed)) {
        ::close(fd);
        return false;
    }
    // A truncated legacy file may have an oversized length header. Preserve the
    // parser's bounded partial-read behavior instead of allocating that length.
    size_t bytes = static_cast<size_t>(std::min<uint64_t>(uint64_t(committed) + 4, info.st_size));
    try { snapshot.resize(bytes); }
    catch (const std::bad_alloc &) { ::close(fd); return false; }
    memcpy(snapshot.data(), &committed, 4);
    size_t copied = 4;
    while (copied < bytes) {
        do { result = ::read(fd, snapshot.data() + copied, bytes - copied); } while (result < 0 && errno == EINTR);
        if (result <= 0) break;
        copied += static_cast<size_t>(result);
    }
    ::close(fd);
    snapshot.resize(copied);
    return result >= 0;
}

} // namespace ipc
} // namespace mxlogger
#endif
#endif
