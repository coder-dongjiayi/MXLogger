#include "mx_test.hpp"
#include "mxlogger_windows_write_time.hpp"

using mxlogger::files::windows_write_time;
namespace {
constexpr uint64_t second = windows_write_time::ticks_per_second;
struct clock_writer {
    std::vector<uint64_t> published;
    bool fail = false;
    bool operator()(uint64_t value) {
        if (fail) return false;
        published.push_back(value);
        return true;
    }
};
bool append(windows_write_time& time, uint64_t now, clock_writer& writer) {
    if (!time.prepare(now, [&](uint64_t value) { return writer(value); })) return false;
    time.commit(now);
    return true;
}
bool flush(windows_write_time& time, clock_writer& writer) {
    return time.flush([&](uint64_t value) { return writer(value); });
}
}

MX_TEST(write_time, same_second_burst_publishes_once_and_flushes_latest_commit) {
    windows_write_time time;
    clock_writer writer;
    for (uint64_t i = 0; i < 100000; ++i) EXPECT_TRUE(append(time, 100 * second + i, writer));
    EXPECT_EQ(writer.published.size(), size_t(1));
    EXPECT_EQ(writer.published.front(), 100 * second);
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.size(), size_t(2));
    EXPECT_EQ(writer.published.back(), 100 * second + 99999);
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.size(), size_t(2));
}

MX_TEST(write_time, identical_clock_ticks_still_require_release_flush) {
    windows_write_time time;
    clock_writer writer;
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_EQ(writer.published.size(), size_t(1));
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.size(), size_t(2));
}

MX_TEST(write_time, second_boundary_and_clock_rollback_publish_before_commit) {
    windows_write_time time;
    clock_writer writer;
    for (uint64_t value : {100 * second - 1, 100 * second, 99 * second, 100 * second}) {
        EXPECT_TRUE(time.prepare(value, [&](uint64_t tick) { return writer(tick); }));
        EXPECT_EQ(writer.published.back(), value);
        EXPECT_FALSE(time.coalesced());
        time.commit(value);
    }
    EXPECT_EQ(writer.published.size(), size_t(4));
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.size(), size_t(4));
}

MX_TEST(write_time, killed_writer_needs_no_flush_for_cleanup_second) {
    windows_write_time time;
    clock_writer writer;
    for (uint64_t tick : {100 * second, 100 * second + 9, 101 * second, 101 * second + 42}) {
        EXPECT_TRUE(append(time, tick, writer));
        // The OS-visible mtime second already matches every committed append,
        // even if termination prevents all later flush/close callbacks.
        EXPECT_EQ(writer.published.back() / second, tick / second);
    }
    EXPECT_EQ(writer.published.size(), size_t(2));
}

MX_TEST(write_time, failed_publish_is_retried_and_does_not_commit_timestamp) {
    windows_write_time time;
    clock_writer writer;
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_TRUE(append(time, 100 * second + 1, writer));
    writer.fail = true;
    EXPECT_FALSE(append(time, 101 * second, writer));
    EXPECT_FALSE(flush(time, writer));
    writer.fail = false;
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.back(), 100 * second + 1);
    EXPECT_TRUE(append(time, 101 * second, writer));
    EXPECT_EQ(writer.published.back(), 101 * second);
}

MX_TEST(write_time, failed_release_forces_retry_even_in_the_same_second) {
    windows_write_time time;
    clock_writer writer;
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_TRUE(append(time, 100 * second + 1, writer));
    writer.fail = true;
    EXPECT_FALSE(flush(time, writer));
    EXPECT_FALSE(append(time, 100 * second + 2, writer));
    writer.fail = false;
    EXPECT_TRUE(append(time, 100 * second + 3, writer));
    EXPECT_FALSE(time.coalesced());
    EXPECT_EQ(writer.published.back(), 100 * second + 3);
}

MX_TEST(write_time, reopening_same_second_does_not_reuse_previous_file_state) {
    windows_write_time time;
    clock_writer writer;
    EXPECT_TRUE(append(time, 100 * second, writer));
    time.reset();
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_EQ(writer.published.size(), size_t(2));
}

MX_TEST(write_time, diagnostic_opt_out_preserves_per_record_updates) {
    windows_write_time time;
    clock_writer writer;
    time.set_coalescing(false);
    for (int i = 0; i < 100; ++i) EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_EQ(writer.published.size(), size_t(100));
    EXPECT_TRUE(flush(time, writer));
    EXPECT_EQ(writer.published.size(), size_t(100));
    time.reset();
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_TRUE(append(time, 100 * second, writer));
    EXPECT_EQ(writer.published.size(), size_t(102));
}
