#ifndef MXLOGGER_MACOS_PROFILE_HPP
#define MXLOGGER_MACOS_PROFILE_HPP

#include "mxlogger_platform.hpp"
#if defined(MXLOGGER_MACOS_PROFILING) && MXLOGGER_MACOS_MULTIPROCESS
#include <mach/mach_time.h>
#include <array>
#include <cstdint>

namespace mxlogger { namespace profile {
enum class stage : size_t {
    swift_other, message, objc_bridge, core_other, thread_mutex, metadata,
    serialization, encryption, transaction_other, directory_lock, directory_unlock,
    mapping_refresh, file_info, path_stat, file_open, file_close, resize,
    mapping, unmapping, growth_other, append, count
};
inline constexpr const char* names[] = {
    "swift_other", "message_format", "objc_bridge", "core_other", "thread_mutex", "metadata",
    "serialization", "encryption", "transaction_other", "directory_lock", "directory_unlock",
    "mapping_refresh", "file_info", "path_stat", "file_open", "file_close", "resize",
    "mapping", "unmapping", "growth_other", "append"
};
struct metric {
    uint64_t calls = 0, sampled_calls = 0, exact_calls = 0;
    uint64_t sampled_ticks = 0, exact_ticks = 0;
};
struct frame { stage id; bool exact; uint64_t start, children; };
struct state {
    bool enabled = false, in_record = false, sampled = false;
    uint64_t records = 0, sampled_records = 0, overflow = 0;
    uint32_t stride = 64, offset = 0, depth = 0;
    std::array<metric, static_cast<size_t>(stage::count)> metrics{};
    std::array<frame, 32> stack{};
};
inline thread_local state current;
inline bool enter(stage id, bool exact = false) {
    auto& s = current;
    if (!s.enabled || !s.in_record) return false;
    ++s.metrics[static_cast<size_t>(id)].calls;
    if (!exact && !s.sampled) return false;
    if (s.depth == s.stack.size()) { ++s.overflow; return false; }
    s.stack[s.depth++] = {id, exact, mach_absolute_time(), 0};
    return true;
}
inline void leave() {
    auto& s = current;
    const auto f = s.stack[--s.depth];
    const uint64_t elapsed = mach_absolute_time() - f.start;
    auto& value = s.metrics[static_cast<size_t>(f.id)];
    const uint64_t exclusive = elapsed >= f.children ? elapsed - f.children : 0;
    if (f.exact) { ++value.exact_calls; value.exact_ticks += exclusive; }
    else { ++value.sampled_calls; value.sampled_ticks += exclusive; }
    if (s.depth) s.stack[s.depth - 1].children += elapsed;
}
class scope {
public:
    scope(stage id, bool exact = false) : active_(enter(id, exact)) {}
    ~scope() { stop(); }
    void stop() { if (active_) { leave(); active_ = false; } }
    scope(const scope&) = delete;
    scope& operator=(const scope&) = delete;
private:
    bool active_;
};
inline void start(uint32_t stride, uint32_t offset) {
    current = {};
    current.stride = stride ? stride : 1;
    current.offset = offset % current.stride;
    current.enabled = true;
}
inline bool record_begin(uint64_t index) {
    auto& s = current;
    s.in_record = true;
    ++s.records;
    s.sampled = index % s.stride == s.offset;
    if (s.sampled) ++s.sampled_records;
    enter(stage::swift_other);
    return s.sampled;
}
inline void record_end() {
    if (current.sampled) leave();
    current.in_record = false;
    current.sampled = false;
}
inline double nanoseconds(uint64_t ticks) {
    static const auto scale = [] { mach_timebase_info_data_t t{}; mach_timebase_info(&t); return t; }();
    return static_cast<double>(ticks) * scale.numer / scale.denom;
}
}}
#define MXP_SCOPE(name, id) ::mxlogger::profile::scope name(::mxlogger::profile::stage::id)
#define MXP_EXACT(name, id) ::mxlogger::profile::scope name(::mxlogger::profile::stage::id, true)
#define MXP_STOP(name) name.stop()
#else
#define MXP_SCOPE(name, id) ((void)0)
#define MXP_EXACT(name, id) ((void)0)
#define MXP_STOP(name) ((void)0)
#endif
#endif
