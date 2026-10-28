#ifndef mxlogger_interprocess_hpp
#define mxlogger_interprocess_hpp

#include "mxlogger_file.hpp"
#if MXLOGGER_MULTIPROCESS
#include <cstring>
#include <new>
#include <stdexcept>
#include <vector>

namespace mxlogger {
namespace ipc {

constexpr const char *lock_filename = ".mxlogger.lock";

inline std::string parent_directory(const std::string &path) {
#ifdef _WIN32
    auto slash = path.find_last_of("/\\");
#else
    auto slash = path.find_last_of('/');
#endif
    return slash == std::string::npos ? "./" : path.substr(0, slash + 1);
}

inline std::string coordination_path(const std::string &directory) {
    if (directory.empty()) return std::string("./") + lock_filename;
    const char last = directory.back();
    bool separator = last == '/';
#ifdef _WIN32
    separator = separator || last == '\\';
#endif
    return directory + (separator ? "" : "/") + lock_filename;
}

// Persistent and excluded from cleanup. Each lock owns its OS handle so readers
// cannot downgrade a writer's lock through a reused fd. Acquire the thread
// mutex first; recursive locking and shared-to-exclusive upgrades are forbidden.
class directory_lock {
public:
    explicit directory_lock(const std::string &directory, bool create = true)
        : path_(coordination_path(directory)), create_(create) {}
    bool lock(bool exclusive) {
        if (!file_.valid() && !file_.open(path_, !create_, create_, false)) {
            return !create_ && files::is_missing(file_.error());
        }
        return file_.lock(exclusive);
    }
    void unlock() { if (file_.valid()) file_.unlock(); }
    std::string error_message() const { return file_.error_message(); }
    directory_lock(const directory_lock &) = delete;
    directory_lock &operator=(const directory_lock &) = delete;
private:
    std::string path_;
    bool create_;
    files::native_file file_;
};

class scoped_lock {
public:
    explicit scoped_lock(directory_lock &lock, bool exclusive = true)
        : lock_(lock), locked_(lock.lock(exclusive)) {}
    ~scoped_lock() { if (locked_) lock_.unlock(); }
    explicit operator bool() const { return locked_; }
    std::string error_message() const { return lock_.error_message(); }
    scoped_lock(const scoped_lock &) = delete;
    scoped_lock &operator=(const scoped_lock &) = delete;
private:
    directory_lock &lock_;
    bool locked_;
};

#ifdef _WIN32
// Byte zero coordinates transactions. Other ranges hold shared live-file leases
// so idle writers can close data files and release views before any expansion.
// Hash the OS identity, not path spelling. Collisions conservatively preserve
// extra files; they cannot cause an active file to be deleted.
inline uint64_t lease_offset(const files::file_info &info) {
    uint64_t value = 14695981039346656037ULL;
    for (uint64_t word : {info.volume, info.index}) {
        for (int i = 0; i < 8; ++i) {
            value ^= (word >> (8 * i)) & 0xff;
            value *= 1099511628211ULL;
        }
    }
    return (value & 0x7fffffffffffffffULL) | 1;
}

class active_file_lease {
public:
    bool hold(const std::string &directory, const files::file_info &info) {
        const uint64_t next = lease_offset(info);
        if (held_ && next == offset_) return true;
        if (!file_.valid() && !file_.open(coordination_path(directory), false, true, false)) return false;
        if (!file_.lock(false, true, next)) return false;
        if (held_) file_.unlock(offset_);
        offset_ = next;
        held_ = true;
        return true;
    }
    std::string error_message() const { return file_.error_message(); }
private:
    files::native_file file_;
    uint64_t offset_ = 0;
    bool held_ = false;
};
#endif

// Caller holds the directory's exclusive lock. macOS leases are shared flocks
// on data fds; Windows leases use identities and separate coordinator handles.
inline bool file_is_inactive(const std::string &path) {
    files::native_file file;
    if (!file.open(path, true)) return false;
#ifdef _WIN32
    files::file_info info;
    if (!file.info(info)) return false;
    files::native_file coordinator;
    if (!coordinator.open(coordination_path(parent_directory(path)), true, false, false)) return false;
    return coordinator.lock(true, false, lease_offset(info));
#else
    return file.lock(true, false);
#endif
}

// Copy committed bytes under a shared lock; decrypt and parse after releasing
// it. Windows snapshots use a read-only view, coherent with mapped writers.
inline bool read_snapshot(const char *path, std::vector<uint8_t> &snapshot) {
    directory_lock directory_lock(parent_directory(path), false);
    scoped_lock lock(directory_lock, false);
    if (!lock) return false;
    files::native_file file;
    files::file_info info;
    if (!file.open(path, true) || !file.info(info) || info.size < sizeof(uint32_t) ||
        info.size > std::numeric_limits<size_t>::max()) return false;
    uint32_t committed = 0;
#ifdef _WIN32
    files::mapped_view view;
    if (!view.map(file, static_cast<size_t>(info.size), false)) return false;
    memcpy(&committed, view.data(), sizeof(committed));
#else
    if (file.read(&committed, sizeof(committed)) != sizeof(committed)) return false;
#endif
    const size_t bytes = static_cast<size_t>(std::min<uint64_t>(uint64_t(committed) + 4, info.size));
    try { snapshot.resize(bytes); }
    catch (const std::bad_alloc &) { return false; }
    catch (const std::length_error &) { return false; }
#ifdef _WIN32
    memcpy(snapshot.data(), view.data(), bytes);
#else
    memcpy(snapshot.data(), &committed, 4);
    size_t copied = 4;
    while (copied < bytes) {
        auto count = file.read(snapshot.data() + copied, bytes - copied);
        if (count <= 0) return false;
        copied += static_cast<size_t>(count);
    }
#endif
    return true;
}

} // namespace ipc
} // namespace mxlogger
#endif
#endif
