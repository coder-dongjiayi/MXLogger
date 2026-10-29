#ifndef MXLOGGER_WINDOWS_CACHE_HPP
#define MXLOGGER_WINDOWS_CACHE_HPP

#ifdef _WIN32
#include "mxlogger_file.hpp"
#include <atomic>
#include <mutex>
#include <thread>

namespace mxlogger {
namespace ipc {

// Byte 0 still serializes directory transactions. Byte 2 protects retained
// Windows mappings; existing live-file leases use odd offsets, so cannot
// overlap it. Every exclusive directory transaction participates, including
// cleanup and callers which never retain a mapping themselves.
//
// Lock order: directory byte 0 -> this object's mutex -> mapping byte 2.
// The eviction thread takes ONLY the mutex. It can therefore unmap/close and
// release byte 2 while another process owns byte 0 and waits for that release.
class windows_mapping_cache {
public:
    using release_function = bool (*)(void *);
    windows_mapping_cache() = default;
    ~windows_mapping_cache() {
        stop();
        if (request_) CloseHandle(request_);
    }
    windows_mapping_cache(const windows_mapping_cache &) = delete;
    windows_mapping_cache &operator=(const windows_mapping_cache &) = delete;

    void configure(void *context, release_function release) {
        context_ = context;
        release_ = release;
    }
    void clear_error() { error_ = ERROR_SUCCESS; }
    DWORD error() const { return error_.load(); }

    // Called after taking directory byte 0. A successful enter holds mutex_
    // until leave(), protecting sink state against the eviction thread.
    bool enter(const std::string &path) {
        mutex_.lock();
        if (held_) return true;
        try {
            if (!initialize(path)) { mutex_.unlock(); return false; }
        } catch (...) { return fail(ERROR_NOT_ENOUGH_MEMORY); }
        if (!gate_.lock(true, false, mapping_offset)) {
            const auto failure = gate_.error();
            if (failure.value() != ERROR_LOCK_VIOLATION) return fail(failure.value());
            // Contended writers use transient mappings for a short interval,
            // rather than paying a background-thread handoff on every record.
            cooldown_until_ = GetTickCount64() + cooldown_ms;
            // An event may be inaccessible across user/security boundaries.
            // The bounded lease below still releases idle mappings in that
            // case; permission to the coordinator file remains authoritative.
            if (request_) SetEvent(request_);
            const ULONGLONG deadline = GetTickCount64() + 5000;
            while (!gate_.lock(true, false, mapping_offset)) {
                const auto next = gate_.error();
                if (next.value() != ERROR_LOCK_VIOLATION) return fail(next.value());
                if (GetTickCount64() >= deadline) return fail(ERROR_TIMEOUT);
                Sleep(1);
            }
        }
        held_ = true;
        if (request_ && !ResetEvent(request_)) {
            const DWORD failure = GetLastError();
            gate_.unlock(mapping_offset); held_ = false;
            return fail(failure);
        }
        return true;
    }
    bool cached() const { return held_ && cached_; } // Caller holds mutex_.
    bool can_retain() const {
        return release_ && request_ && GetTickCount64() >= cooldown_until_;
    }

    // A failed/empty mapping is never retained. Thread/event allocation failure
    // safely falls back to the old transient lifetime, not unlocked access.
    bool retain(bool valid) {
        retain_ = valid && can_retain() && start_worker();
        return retain_;
    }
    bool discard() { // Caller holds mutex_ and directory byte 0.
        retain_ = false;
        cached_ = false;
        return !release_ || release_(context_);
    }
    void leave() {
        if (retain_ && arm_worker()) {
            cached_ = true;
        } else {
            if (ready_) ResetEvent(ready_);
            ready_signaled_ = false;
            // Transactions without an mmap cleanup guard (e.g. remove_all)
            // must also finish with the view closed before releasing byte 2.
            if (!release_ || release_(context_)) {
                cached_ = false;
                if (held_) gate_.unlock(mapping_offset);
                held_ = false;
            } else {
                error_ = ERROR_WRITE_FAULT;
                // Do not release protection around a view that failed to close.
                cached_ = true;
                if (start_worker()) arm_worker();
            }
        }
        retain_ = false;
        mutex_.unlock();
    }
    // Must run in mmap_sink's destructor BEFORE its mapping/file members die.
    void stop() {
        if (stop_) SetEvent(stop_);
        if (worker_.joinable()) worker_.join();
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (!release_ || release_(context_)) {
                if (held_) gate_.unlock(mapping_offset);
                held_ = false;
            }
            release_ = nullptr; context_ = nullptr;
            cached_ = false; retain_ = false;
            ready_signaled_ = false;
        }
        if (ready_) { CloseHandle(ready_); ready_ = nullptr; }
        if (stop_) { CloseHandle(stop_); stop_ = nullptr; }
    }
private:
    static constexpr uint64_t mapping_offset = 2;
    static constexpr ULONGLONG cooldown_ms = 250;
    static constexpr DWORD lease_ms = 500;
    files::native_file gate_;
    HANDLE request_ = nullptr, ready_ = nullptr, stop_ = nullptr;
    std::mutex mutex_;
    std::thread worker_;
    std::atomic<DWORD> error_{ERROR_SUCCESS};
    void *context_ = nullptr;
    release_function release_ = nullptr;
    bool held_ = false, cached_ = false, retain_ = false;
    bool ready_signaled_ = false; // Guarded by mutex_, like cached_.
    ULONGLONG cooldown_until_ = 0;

    bool fail(DWORD error) { error_ = error; mutex_.unlock(); return false; }
    bool initialize(const std::string &path) {
        if (gate_.valid()) return true;
        if (!gate_.open(path, false, false, false)) { error_ = gate_.error().value(); return false; }
        files::file_info info;
        if (!gate_.info(info)) { error_ = gate_.error().value(); gate_.close(); return false; }
        // File identity also covers relative/absolute paths, case and aliases.
        // Global events work across Windows sessions and need no global-file-
        // mapping privilege. File locks, not the event, enforce correctness.
        const std::wstring name = L"Global\\MXLogger-map-cache-v1-" +
            std::to_wstring(info.volume) + L"-" + std::to_wstring(info.index);
        request_ = CreateEventW(nullptr, TRUE, FALSE, name.c_str());
        // If events are unavailable, never retain a mapping. An uncontended
        // byte-2 transaction can still use the safe transient implementation.
        return true;
    }
    bool arm_worker() { // Caller holds mutex_.
        // This manual-reset event stays signaled for the whole monitoring
        // interval. Repeated appends need no further kernel notification.
        if (ready_signaled_) return true;
        if (!ready_ || !SetEvent(ready_)) return false;
        ready_signaled_ = true;
        return true;
    }
    bool start_worker() {
        if (worker_.joinable()) return true;
        if (!release_ || !request_) return false;
        stop_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        ready_ = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (stop_ && ready_) {
            try { worker_ = std::thread([this] { watch(); }); return true; }
            catch (...) {} // Retention is optional; the transaction is not.
        }
        if (stop_) { CloseHandle(stop_); stop_ = nullptr; }
        if (ready_) { CloseHandle(ready_); ready_ = nullptr; }
        return false;
    }
    void watch() noexcept {
        HANDLE armed[] = {stop_, ready_};
        HANDLE requested[] = {stop_, request_};
        while (WaitForMultipleObjects(2, armed, FALSE, INFINITE) == WAIT_OBJECT_0 + 1) {
            const DWORD result = WaitForMultipleObjects(2, requested, FALSE, lease_ms);
            if (result != WAIT_OBJECT_0 + 1 && result != WAIT_TIMEOUT) break;
            std::lock_guard<std::mutex> lock(mutex_);
            ResetEvent(ready_);
            // Rearm on the next retained mapping, even if release_ fails.
            ready_signaled_ = false;
            if (!held_ || !cached_) continue;
            // Timeout bounds idle retention even if another user cannot signal
            // the named event. It is not evidence of contention: do not impose
            // a transient cooldown on an otherwise uncontended writer.
            if (result == WAIT_OBJECT_0 + 1) cooldown_until_ = GetTickCount64() + cooldown_ms;
            // Release callback must neither acquire byte 0 nor touch logger
            // settings/encryption/error_record. Foreground writes are excluded
            // by mutex_, including writes in a different thread of this process.
            if (release_ && release_(context_)) {
                cached_ = false;
                gate_.unlock(mapping_offset);
                held_ = false;
            } else error_ = ERROR_WRITE_FAULT;
        }
    }
};
} // namespace ipc
} // namespace mxlogger
#endif // _WIN32
#endif
