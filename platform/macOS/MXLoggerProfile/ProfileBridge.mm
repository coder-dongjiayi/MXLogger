#import "ProfileBridge.h"
#include "mxlogger.hpp"
#include "mxlogger_profile.hpp"
#include <sys/resource.h>
#include <chrono>
#include <stdexcept>
#include <string>
#include <vector>

bool MXPInstrumented() {
#ifdef MXLOGGER_MACOS_PROFILING
    return true;
#else
    return false;
#endif
}
void MXPStart(uint32_t stride, uint32_t offset) {
#ifdef MXLOGGER_MACOS_PROFILING
    mxlogger::profile::start(stride, offset);
#endif
}
void MXPRecordBegin(uint64_t index) {
#ifdef MXLOGGER_MACOS_PROFILING
    mxlogger::profile::record_begin(index);
#endif
}
void MXPMessageBegin() {
#ifdef MXLOGGER_MACOS_PROFILING
    mxlogger::profile::enter(mxlogger::profile::stage::message);
#endif
}
void MXPMessageEnd() {
#ifdef MXLOGGER_MACOS_PROFILING
    if (mxlogger::profile::current.sampled) mxlogger::profile::leave();
#endif
}
void MXPRecordEnd() {
#ifdef MXLOGGER_MACOS_PROFILING
    mxlogger::profile::record_end();
#endif
}
const char* MXPFinishJSON() {
    static thread_local std::string output;
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
#ifdef MXLOGGER_MACOS_PROFILING
    using namespace mxlogger::profile;
    current.enabled = false;
    NSMutableArray* stages = [NSMutableArray array];
    for (size_t i = 0; i < static_cast<size_t>(stage::count); ++i) {
        const auto& m = current.metrics[i];
        const double sampled = nanoseconds(m.sampled_ticks);
        const double exact = nanoseconds(m.exact_ticks);
        const double estimate = exact + (current.sampled_records ? sampled * current.records / current.sampled_records : 0);
        [stages addObject:@{@"name": @(names[i]), @"calls": @(m.calls),
            @"sampled_calls": @(m.sampled_calls), @"exact_calls": @(m.exact_calls),
            @"sampled_ns": @(sampled), @"exact_ns": @(exact), @"estimated_ns": @(estimate)}];
    }
    result[@"stages"] = stages;
    result[@"records"] = @(current.records);
    result[@"sampled_records"] = @(current.sampled_records);
    result[@"sample_stride"] = @(current.stride);
    result[@"sample_offset"] = @(current.offset);
    result[@"stack_overflow"] = @(current.overflow);
    result[@"unclosed_scopes"] = @(current.depth);
    // Report clock cost separately; do not mechanically subtract it from stages.
    const uint64_t start = mach_absolute_time();
    uint64_t sink = 0;
    for (int i = 0; i < 100000; ++i) sink ^= mach_absolute_time();
    result[@"clock_read_ns"] = @(nanoseconds(mach_absolute_time() - start) / 100000);
    result[@"clock_checksum"] = @(sink);
#endif
    NSData* data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    output.assign(static_cast<const char*>(data.bytes), data.length);
    return output.c_str();
}
NSString* MXPCoreVersion() { return @(mx_logger::version()); }
void MXPFlushLogger(NSString* token) {
    if (auto* logger = mx_logger::global_for_loggerToken(token.UTF8String)) logger->flush();
}
NSDictionary* MXPResources() {
    rusage r{}; getrusage(RUSAGE_SELF, &r);
    return @{@"user_seconds": @(r.ru_utime.tv_sec + r.ru_utime.tv_usec / 1e6),
        @"system_seconds": @(r.ru_stime.tv_sec + r.ru_stime.tv_usec / 1e6),
        @"minor_faults": @(r.ru_minflt), @"major_faults": @(r.ru_majflt),
        @"voluntary_switches": @(r.ru_nvcsw), @"involuntary_switches": @(r.ru_nivcsw),
        @"max_rss_bytes": @(r.ru_maxrss)};
}
NSDictionary* MXPCoreRun(NSString* directory, NSArray<NSString*>* messages, BOOL encrypted) {
    std::vector<std::string> utf8;
    utf8.reserve(messages.count);
    for (NSString* message in messages) utf8.emplace_back(message.UTF8String);
    const char* ns = "com.djy.mxlogger.profile.core";
    auto* logger = mx_logger::initialize_namespace(ns, directory.UTF8String, "yyyy_MM_dd_HH", nullptr,
        "{\"platform\":\"macOS\",\"appVersion\":\"2.2.0\",\"from\":\"native-demo\"}",
        encrypted ? "abcdefgabcdefgob" : nullptr, encrypted ? "abcdefgabcdefgcc" : nullptr);
    if (!logger) return @{@"error": @"Core initialization failed"};
    logger->set_enable_console(false);
    logger->set_file_max_age(7 * 24 * 60 * 60);
    logger->set_file_max_size(10 * 1024 * 1024);
    const std::string path = logger->diskcache_path();
    int status = 0;
    NSDictionary* before = MXPResources();
    const auto start = std::chrono::steady_clock::now();
    for (const auto& message : utf8) {
        status = logger->log(1, "benchmark", message.c_str(), "perf", false);
        if (status != 0) break;
    }
    const double seconds = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
    NSDictionary* after = MXPResources();
    NSString* error = status == 0 ? @"" : @(logger->error_desc());
    logger->flush();
    mx_logger::delete_namespace(ns, directory.UTF8String);
    return @{@"seconds": @(seconds), @"path": @(path.c_str()), @"error": error,
        @"resource_before": before, @"resource_after": after};
}
