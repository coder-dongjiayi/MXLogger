#ifndef MXLOGGER_PROFILE_HPP
#define MXLOGGER_PROFILE_HPP

// Only the separate diagnostic Core target enables these hooks. Normal builds
// contain no collector, thread-local accesses, counters or clock reads.
#if defined(MXLOGGER_ENABLE_PROFILING) && MXLOGGER_ENABLE_PROFILING
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <stdexcept>

namespace mxlogger { namespace profiling {
enum class phase : size_t {
    other, message, thread_mutex, metadata, serialization, encryption,
    directory_lock, directory_unlock, cache_mutex, cache_coordination, handoff_wait,
    mapping_refresh, file_open, file_close, mapping, unmapping, resize, file_time, append, count
};
inline constexpr const char* phase_names[] = {
    "other", "message", "thread_mutex_wait", "metadata", "serialization_and_allocation",
    "aes", "directory_lock", "directory_unlock", "cache_mutex_wait", "cache_coordination", "mapping_handoff_wait",
    "mapping_refresh", "file_open", "file_close", "map", "unmap", "resize", "file_time", "append"
};
enum class counter : size_t { cache_hit, cache_miss, handoff, ready_set, ready_reused, request_set, count };
inline constexpr const char* counter_names[] = {
    "cache_hits", "cache_misses", "mapping_handoffs", "ready_set_events", "ready_reused", "request_set_events"
};
struct measurement {
    uint64_t calls = 0, sampled_calls = 0, exact_calls = 0;
    uint64_t sampled_ns = 0, exact_ns = 0;
};
struct snapshot {
    std::array<measurement, static_cast<size_t>(phase::count)> phases{};
    std::array<uint64_t, static_cast<size_t>(counter::count)> counters{};
    uint64_t records = 0, sampled_records = 0;
    uint32_t stride = 64, offset = 0;
};
class span;
struct collector {
    snapshot result;
    span* top = nullptr;
    bool running = false, in_record = false, sampled = false;
};
inline thread_local collector local;
inline uint64_t now_ns() noexcept {
    return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count());
}
inline void begin(uint32_t stride = 64, uint32_t offset = 0) {
    if (!stride || local.running) throw std::logic_error("Invalid or nested profiling run");
    local = {};
    local.result.stride = stride;
    local.result.offset = offset % stride;
    local.running = true;
}
inline snapshot finish() {
    if (!local.running || local.in_record || local.top) throw std::logic_error("Profiling scopes still active");
    local.running = false;
    return local.result;
}
inline void cancel() noexcept { local = {}; }
inline void increment(counter key) noexcept {
    if (local.in_record) ++local.result.counters[static_cast<size_t>(key)];
}
class span {
public:
    span() = default;
    explicit span(phase key, bool exact = false, bool enabled = true) noexcept {
        if (enabled) start(key, exact);
    }
    void start(phase key, bool exact = false) noexcept {
        if (!local.in_record) return;
        auto& metric = local.result.phases[static_cast<size_t>(key)];
        ++metric.calls;
        // A fully timed rare operation also times its descendants fully. This
        // keeps exclusive accounting valid without extrapolating those children.
        exact_ = exact || (local.top && local.top->exact_);
        if (!exact_ && !local.sampled) return;
        metric_ = &metric;
        parent_ = local.top;
        local.top = this;
        started_ = now_ns();
    }
    ~span() { stop(); }
    void stop() noexcept {
        if (!metric_) return;
        const uint64_t elapsed = now_ns() - started_;
        const uint64_t exclusive = elapsed > children_ ? elapsed - children_ : 0;
        if (exact_) { ++metric_->exact_calls; metric_->exact_ns += exclusive; }
        else { ++metric_->sampled_calls; metric_->sampled_ns += exclusive; }
        if (parent_) parent_->children_ += elapsed;
        local.top = parent_;
        metric_ = nullptr;
    }
    span(const span&) = delete;
    span& operator=(const span&) = delete;
private:
    measurement* metric_ = nullptr;
    span* parent_ = nullptr;
    uint64_t started_ = 0, children_ = 0;
    bool exact_ = false;
};
class record {
public:
    record() noexcept : active_(local.running && !local.in_record) {
        if (!active_) return;
        const uint64_t index = local.result.records++;
        local.in_record = true;
        local.sampled = index % local.result.stride == local.result.offset;
        if (local.sampled) ++local.result.sampled_records;
        remainder_.start(phase::other);
    }
    ~record() {
        if (active_) { remainder_.stop(); local.in_record = false; local.sampled = false; }
    }
    record(const record&) = delete;
    record& operator=(const record&) = delete;
private:
    bool active_;
    span remainder_;
};
inline double estimated_ns(const snapshot& result, const measurement& metric) {
    const double scale = result.sampled_records ? double(result.records) / result.sampled_records : 0;
    return double(metric.exact_ns) + double(metric.sampled_ns) * scale;
}
}} // namespace mxlogger::profiling

#define MXLOGGER_PROFILE_RECORD() ::mxlogger::profiling::record mxlogger_profile_record
#define MXLOGGER_PROFILE_SPAN(name, key) ::mxlogger::profiling::span name(::mxlogger::profiling::phase::key)
#define MXLOGGER_PROFILE_EXACT(name, key) ::mxlogger::profiling::span name(::mxlogger::profiling::phase::key, true)
#define MXLOGGER_PROFILE_IF(name, key, enabled) ::mxlogger::profiling::span name(::mxlogger::profiling::phase::key, false, enabled)
#define MXLOGGER_PROFILE_STOP(name) name.stop()
#define MXLOGGER_PROFILE_COUNT(key) ::mxlogger::profiling::increment(::mxlogger::profiling::counter::key)
#else
#define MXLOGGER_PROFILE_RECORD() ((void)0)
#define MXLOGGER_PROFILE_SPAN(name, key) ((void)0)
#define MXLOGGER_PROFILE_EXACT(name, key) ((void)0)
#define MXLOGGER_PROFILE_IF(name, key, enabled) ((void)0)
#define MXLOGGER_PROFILE_STOP(name) ((void)0)
#define MXLOGGER_PROFILE_COUNT(key) ((void)0)
#endif
#endif
