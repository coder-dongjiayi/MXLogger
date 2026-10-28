#include "demo_model.hpp"
#include "mxlogger_file.hpp"
#include "mxlogger_profile.hpp"
#include "json/cJSON.h"
#include <algorithm>
#include <array>
#include <fstream>
#include <iostream>
#include <memory>
#include <numeric>
#include <stdexcept>

namespace {
namespace fs = std::filesystem;
namespace profile = mxlogger::profiling;
using Json = std::unique_ptr<cJSON, decltype(&cJSON_Delete)>;
struct Options {
    fs::path directory;
    int records = 100000;
    uint32_t stride = 64, offset = 0;
    bool microbench = false;
};
void require(bool value, const std::string& message) {
    if (!value) throw std::runtime_error(message);
}
uint32_t number(const std::string& value, uint32_t maximum) {
    require(!value.empty() && value.find_first_not_of("0123456789") == std::string::npos, "Expected an unsigned integer");
    const auto result = std::stoull(value);
    require(result <= maximum, "Numeric option exceeds its limit");
    return static_cast<uint32_t>(result);
}
Options parse(int argc, char** argv) {
    Options options;
    for (int i = 1; i < argc; ++i) {
        const std::string key = argv[i];
        if (key == "--microbench") { options.microbench = true; continue; }
        require(i + 1 < argc, "Missing option value: " + key);
        const std::string value = argv[++i];
        if (key == "--report-dir") options.directory = fs::absolute(fs::u8path(value));
        else if (key == "--records") options.records = static_cast<int>(number(value, 1000000));
        else if (key == "--sample-stride") options.stride = number(value, 65536);
        else if (key == "--sample-offset") options.offset = number(value, 65535);
        else throw std::runtime_error("Unknown option: " + key);
    }
    require(!options.directory.empty() && options.records > 0 && options.stride > 0,
            "Usage: MXLoggerProfile --report-dir <directory> [--records 100000] [--sample-stride 64] [--sample-offset 0] [--microbench]");
    require(options.microbench || options.offset % options.stride < static_cast<uint32_t>(options.records),
            "Sampling offset would select no records");
    return options;
}
void save_json(const fs::path& path, cJSON* value) {
    char* text = cJSON_Print(value);
    require(text != nullptr, "Could not serialize profile report");
    std::unique_ptr<char, decltype(&cJSON_free)> owned(text, cJSON_free);
    std::ofstream output(path); output << text << '\n';
    require(output.good(), "Could not write " + path.u8string());
}
double clock_pair_ns() {
    std::array<uint64_t, 1001> values{};
    for (auto& value : values) {
        const auto start = profile::now_ns();
        value = profile::now_ns() - start;
    }
    std::sort(values.begin(), values.end());
    return static_cast<double>(values[values.size() / 2]);
}
void add_stages(cJSON* item, const profile::snapshot& result, double elapsed) {
    auto* stages = cJSON_AddArrayToObject(item, "stages");
    std::array<size_t, static_cast<size_t>(profile::phase::count)> order{};
    std::iota(order.begin(), order.end(), size_t(0));
    std::sort(order.begin(), order.end(), [&](size_t a, size_t b) {
        return profile::estimated_ns(result, result.phases[a]) > profile::estimated_ns(result, result.phases[b]);
    });
    double estimated_total = 0;
    for (size_t key : order) {
        const auto& metric = result.phases[key];
        auto* row = cJSON_CreateObject(); cJSON_AddItemToArray(stages, row);
        cJSON_AddStringToObject(row, "name", profile::phase_names[key]);
        cJSON_AddNumberToObject(row, "calls", static_cast<double>(metric.calls));
        cJSON_AddNumberToObject(row, "sampled_calls", static_cast<double>(metric.sampled_calls));
        cJSON_AddNumberToObject(row, "exact_calls", static_cast<double>(metric.exact_calls));
        cJSON_AddNumberToObject(row, "sampled_exclusive_ms", metric.sampled_ns / 1e6);
        cJSON_AddNumberToObject(row, "exact_exclusive_ms", metric.exact_ns / 1e6);
        // An unobserved conditional stage is unknown, rather than a measured 0.
        const bool known = metric.calls == metric.exact_calls || metric.sampled_calls;
        if (known) {
            const double estimate = profile::estimated_ns(result, metric);
            estimated_total += estimate;
            cJSON_AddNumberToObject(row, "estimated_exclusive_ms", estimate / 1e6);
            cJSON_AddNumberToObject(row, "estimated_share_percent", estimate / (elapsed * 1e7));
            if (metric.calls) cJSON_AddNumberToObject(row, "estimated_mean_us", estimate / (metric.calls * 1000.0));
        } else {
            cJSON_AddNullToObject(row, "estimated_exclusive_ms");
            cJSON_AddNullToObject(row, "estimated_share_percent");
        }
    }
    cJSON_AddNumberToObject(item, "estimated_coverage_percent", estimated_total / (elapsed * 1e7));
    // Keep negative residuals visible: these are sampling estimates, not an
    // artificial 100%-normalized partition or a corrected production runtime.
    cJSON_AddNumberToObject(item, "unattributed_estimate_ms", elapsed * 1000 - estimated_total / 1e6);
    auto* counters = cJSON_AddObjectToObject(item, "counters");
    for (size_t i = 0; i < result.counters.size(); ++i)
        cJSON_AddNumberToObject(counters, profile::counter_names[i], static_cast<double>(result.counters[i]));
}
void run_case(const Options& options, bool encrypted, cJSON* item) {
    demo::Config config;
    config.root = (options.directory / fs::u8path("data-" + demo::unique_id())).u8string();
    config.name_space = encrypted ? "aes" : "plain";
    config.encrypted = encrypted; config.max_age = 0; config.max_size = 0;
    demo::Session session(config);
    demo::Progress progress;
    double elapsed = 0;
    profile::begin(options.stride, options.offset);
    profile::snapshot result;
    try {
        session.benchmark(options.records, progress, &elapsed);
        result = profile::finish();
    } catch (...) { profile::cancel(); throw; }
    // Flush, decoding, validation and JSON allocation all follow finish().
    session.logger()->flush();
    const auto records = session.all_records();
    require(records.size() == static_cast<size_t>(options.records) + 1, "Header/record count mismatch");
    require(demo::field(records.front(), "name") == "com.djy.mxlogger.fileHeader", "Missing header");
    int sequence = 0;
    for (const auto& row : records) {
        require(demo::field(row, "error_code") == "0", "Profile read/decryption failed");
        if (demo::field(row, "name") == "com.djy.mxlogger.fileHeader") continue;
        require(demo::field(row, "tag") == "Benchmark" &&
                demo::field(row, "msg") == "benchmark " + std::to_string(sequence++), "Profile record order mismatch");
    }
    require(sequence == options.records && result.records == static_cast<uint64_t>(options.records) && result.sampled_records,
            "Missing benchmark profiling hooks or samples");
    const auto calls = [&](profile::phase key) { return result.phases[static_cast<size_t>(key)].calls; };
    require(calls(profile::phase::directory_lock) == result.records &&
            calls(profile::phase::directory_unlock) == result.records, "Directory lock instrumentation mismatch");
#ifdef _WIN32
    require(calls(profile::phase::file_time) == result.records, "File time instrumentation mismatch");
    require(result.counters[static_cast<size_t>(profile::counter::cache_hit)] +
            result.counters[static_cast<size_t>(profile::counter::cache_miss)] == result.records,
            "Cache instrumentation mismatch");
#endif
    cJSON_AddNumberToObject(item, "seconds", elapsed);
    cJSON_AddNumberToObject(item, "records", options.records);
    cJSON_AddNumberToObject(item, "sampled_records", static_cast<double>(result.sampled_records));
    cJSON_AddNumberToObject(item, "records_per_second", options.records / elapsed);
    add_stages(item, result, elapsed);
}
void microbench(const Options& options, cJSON* report) {
    auto* cases = cJSON_AddArrayToObject(report, "cases");
    mxlogger::files::native_file file;
    require(file.open((options.directory / fs::u8path("api-" + demo::unique_id() + ".tmp")).u8string(), false, true),
            "Could not create temporary microbenchmark file");
    auto measure = [&](const char* name, const auto& operation) {
        for (int i = 0; i < 1000; ++i) operation();
        const auto start = profile::now_ns();
        for (int i = 0; i < options.records; ++i) operation();
        const double ns = static_cast<double>(profile::now_ns() - start);
        auto* item = cJSON_CreateObject(); cJSON_AddItemToArray(cases, item);
        cJSON_AddStringToObject(item, "name", name);
        cJSON_AddNumberToObject(item, "calls", options.records);
        cJSON_AddNumberToObject(item, "seconds", ns / 1e9);
        cJSON_AddNumberToObject(item, "mean_us", ns / (1000 * options.records));
    };
    measure("uncontended_lock_unlock_pair", [&] {
        if (!file.lock(true) || !file.unlock()) throw std::runtime_error("Microbenchmark lock operation failed");
    });
#ifdef _WIN32
    measure("file_time_update", [&] {
        if (!file.update_write_time()) throw std::runtime_error("Microbenchmark SetFileTime failed");
    });
#endif
    cJSON_AddStringToObject(report, "scope", "Isolated unmapped temporary file; no profiler collection; not directly subtractable from real log() latency");
}
int run(int argc, char** argv) {
    const auto options = parse(argc, argv);
    fs::create_directories(options.directory);
    Json report(cJSON_CreateObject(), cJSON_Delete);
    require(report != nullptr, "Could not allocate profile report");
    cJSON_AddNumberToObject(report.get(), "schema_version", 1);
#ifdef _WIN32
    cJSON_AddStringToObject(report.get(), "backend", "windows");
#else
    cJSON_AddStringToObject(report.get(), "backend", "macos-model-only");
#endif
#ifdef NDEBUG
    cJSON_AddStringToObject(report.get(), "configuration", "Release");
#else
    cJSON_AddStringToObject(report.get(), "configuration", "Debug");
#endif
    cJSON_AddNumberToObject(report.get(), "clock_pair_median_ns", clock_pair_ns());
    cJSON_AddNumberToObject(report.get(), "sample_stride", options.stride);
    cJSON_AddNumberToObject(report.get(), "sample_offset", options.offset % options.stride);
    bool passed = true;
    if (options.microbench) {
        try { microbench(options, report.get()); }
        catch (const std::exception& error) { passed = false; cJSON_AddStringToObject(report.get(), "error", error.what()); }
    } else {
        cJSON_AddStringToObject(report.get(), "scope", "Foreground records only; nested exclusive wall time; background CPU excluded, foreground waits included; no progress or cancellation polling");
        cJSON_AddStringToObject(report.get(), "estimator", "exact_ns + sampled_ns * records / sampled_records; raw estimates may not sum to wall time; no timer-cost subtraction");
        auto* cases = cJSON_AddArrayToObject(report.get(), "cases");
        for (bool encrypted : {false, true}) {
            auto* item = cJSON_CreateObject(); cJSON_AddItemToArray(cases, item);
            cJSON_AddBoolToObject(item, "encrypted", encrypted);
            try { run_case(options, encrypted, item); cJSON_AddBoolToObject(item, "passed", true); }
            catch (const std::exception& error) {
                passed = false; cJSON_AddBoolToObject(item, "passed", false);
                cJSON_AddStringToObject(item, "error", error.what());
            }
        }
    }
    cJSON_AddBoolToObject(report.get(), "passed", passed);
    const auto file = options.directory / (options.microbench ? "microbench.json" : "profile.json");
    save_json(file, report.get());
    std::cout << (passed ? "PASS " : "FAIL ") << file.u8string() << '\n';
    return passed ? 0 : 1;
}
} // namespace
#ifdef _WIN32
int wmain(int argc, wchar_t** argv) {
    try {
        std::vector<std::string> values;
        for (int i = 0; i < argc; ++i) values.push_back(mxlogger::files::to_utf8(argv[i]));
        std::vector<char*> args;
        for (auto& value : values) args.push_back(value.data());
        return run(argc, args.data());
    } catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
#else
int main(int argc, char** argv) {
    try { return run(argc, argv); }
    catch (const std::exception& error) { std::cerr << error.what() << '\n'; return 1; }
}
#endif
