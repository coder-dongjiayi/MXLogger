#include "mx_test.hpp"
#include "mxlogger_profile.hpp"
#include <thread>

namespace p = mxlogger::profiling;

MX_TEST(profile, sampling_counts_rare_children_and_thread_isolation) {
    p::begin(8, 3);
    { p::span outside(p::phase::file_time); }
    for (int i = 0; i < 64; ++i) {
        p::record record;
        p::increment(p::counter::cache_hit);
        p::span serialization(p::phase::serialization);
        if (i == 2 || i == 3) {
            p::span rare(p::phase::mapping, true);
            p::span child(p::phase::cache_mutex);
        }
        if (i == 3) {
            std::thread background([] {
                p::increment(p::counter::cache_miss);
                p::span ignored(p::phase::unmapping, true);
            });
            background.join();
        }
    }
    const auto result = p::finish();
    const auto& serial = result.phases[static_cast<size_t>(p::phase::serialization)];
    const auto& rare = result.phases[static_cast<size_t>(p::phase::mapping)];
    const auto& child = result.phases[static_cast<size_t>(p::phase::cache_mutex)];
    EXPECT_EQ(result.records, uint64_t(64));
    EXPECT_EQ(result.sampled_records, uint64_t(8));
    EXPECT_EQ(serial.calls, uint64_t(64));
    EXPECT_EQ(serial.sampled_calls, uint64_t(8));
    EXPECT_EQ(rare.exact_calls, uint64_t(2));
    EXPECT_EQ(rare.sampled_calls, uint64_t(0));
    EXPECT_EQ(child.exact_calls, uint64_t(2));
    EXPECT_EQ(child.sampled_calls, uint64_t(0));
    EXPECT_EQ(result.counters[static_cast<size_t>(p::counter::cache_hit)], uint64_t(64));
    EXPECT_EQ(result.counters[static_cast<size_t>(p::counter::cache_miss)], uint64_t(0));
    EXPECT_EQ(result.phases[static_cast<size_t>(p::phase::file_time)].calls, uint64_t(0));
    EXPECT_EQ(result.phases[static_cast<size_t>(p::phase::unmapping)].calls, uint64_t(0));
}

MX_TEST(profile, nested_exclusive_time_does_not_double_count) {
    p::begin(1);
    const auto start = p::now_ns();
    {
        p::record record;
        p::span outer(p::phase::serialization);
        { p::span inner(p::phase::encryption); std::this_thread::sleep_for(std::chrono::milliseconds(5)); }
    }
    const auto elapsed = p::now_ns() - start;
    const auto result = p::finish();
    uint64_t total = 0;
    for (const auto& metric : result.phases) total += metric.exact_ns + metric.sampled_ns;
    const auto aes = result.phases[static_cast<size_t>(p::phase::encryption)].sampled_ns;
    EXPECT_TRUE(aes > 0);
    EXPECT_TRUE(total >= aes);
    EXPECT_TRUE(total <= elapsed);
    EXPECT_TRUE(result.phases[static_cast<size_t>(p::phase::serialization)].sampled_ns < total);
}

MX_TEST(profile, exception_unwinds_and_run_can_restart) {
    p::begin(1);
    try {
        p::record record;
        p::span stage(p::phase::append);
        throw std::runtime_error("simulated log failure");
    } catch (const std::runtime_error&) {}
    EXPECT_EQ(p::finish().records, uint64_t(1));
    p::begin(1);
    { p::record record; }
    EXPECT_EQ(p::finish().sampled_records, uint64_t(1));
    bool rejected = false;
    try { p::begin(0); } catch (const std::logic_error&) { rejected = true; }
    EXPECT_TRUE(rejected);
}

int main() { return mxtest::run_all(); }
