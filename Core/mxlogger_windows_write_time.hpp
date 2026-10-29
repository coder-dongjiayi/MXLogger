#ifndef MXLOGGER_WINDOWS_WRITE_TIME_HPP
#define MXLOGGER_WINDOWS_WRITE_TIME_HPP

#include <cstdint>

namespace mxlogger { namespace files {

// FILETIME is measured in 100 ns ticks. Expiration compares whole seconds.
// Keep the policy independent of Windows APIs so boundary/failure behavior can
// be tested deterministically without changing the machine's wall clock.
class windows_write_time {
public:
    static constexpr uint64_t ticks_per_second = 10000000;
    template <typename Publish>
    bool prepare(uint64_t now, Publish publish) {
        prepared_published_ = false;
        if (valid_ && !retry_ && now / ticks_per_second == published_ / ticks_per_second)
            return true;
        // Publish BEFORE the record is committed, including after clock
        // rollback. Even process termination then preserves its cleanup second.
        if (!publish(now)) { retry_ = true; return false; }
        published_ = now;
        valid_ = true;
        retry_ = false;
        prepared_published_ = true;
        return true;
    }
    void commit(uint64_t now) {
        committed_ = now;
        // Mark every coalesced append dirty, even if the system clock returns
        // an identical tick. A release must also repair externally changed mtime.
        dirty_ = !prepared_published_;
    }
    template <typename Publish>
    bool flush(Publish publish) {
        if (!dirty_) return true;
        if (!publish(committed_)) { retry_ = true; return false; }
        published_ = committed_;
        valid_ = true;
        dirty_ = false;
        retry_ = false;
        return true;
    }
    void reset() {
        published_ = committed_ = 0;
        valid_ = dirty_ = retry_ = prepared_published_ = false;
    }
private:
    uint64_t published_ = 0, committed_ = 0;
    bool valid_ = false, dirty_ = false, retry_ = false, prepared_published_ = false;
};

}} // namespace mxlogger::files
#endif
