//
//  test_concurrency.cpp
//  MXLoggerCore 单元测试
//
//  覆盖线程安全: 并发初始化同一namespace单实例、并发写入不丢日志。
//  建议同时用 SAN=thread ./run_tests.sh 在TSan下跑一遍。
//

#include "mx_test.hpp"
#include "test_support.hpp"
#include "mxlogger.hpp"
#include <thread>
#include <vector>
#include <set>

static const char* CC_DIR = "mxtest_tmp/concurrency";

MX_TEST(concurrency, parallel_init_single_instance) {
    const int thread_count = 8;
    std::vector<std::thread> threads;
    std::vector<mx_logger*> results(thread_count, nullptr);

    for (int i = 0; i < thread_count; i++) {
        threads.emplace_back([i, &results]() {
            results[i] = mx_logger::initialize_namespace("shared_ns", CC_DIR,
                                                         nullptr, nullptr, nullptr, nullptr, nullptr);
        });
    }
    for (auto& t : threads) t.join();

    std::set<mx_logger*> unique(results.begin(), results.end());
    EXPECT_EQ(unique.size(), (size_t)1);
    EXPECT_TRUE(*unique.begin() != nullptr);

    mx_logger::destroy();
}

MX_TEST(concurrency, parallel_logging_no_loss) {
    const int thread_count = 8;
    const int per_thread = 50;

    auto* logger = mx_logger::initialize_namespace("cc_log", CC_DIR,
                                                   nullptr, nullptr, nullptr, nullptr, nullptr);
    EXPECT_TRUE(logger != nullptr);

    std::vector<std::thread> threads;
    for (int t = 0; t < thread_count; t++) {
        threads.emplace_back([t, logger]() {
            for (int i = 0; i < per_thread; i++) {
                std::string msg = "t" + std::to_string(t) + "-" + std::to_string(i);
                logger->log(1, "cc", msg.c_str(), "tag", false);
            }
        });
    }
    for (auto& t : threads) t.join();
    logger->flush();

    // 记录数一条不丢
    mxtest::record_list records = mxtest::parse_dir(std::string(logger->diskcache_path()));
    EXPECT_EQ(records.size(), (size_t)(thread_count * per_thread));

    mx_logger::destroy();
}

MX_TEST(concurrency, parallel_init_and_lookup_mixed) {
    // 一半线程抢同一个ns，另一半各建各的，同时穿插key查询
    const int thread_count = 12;
    std::vector<std::thread> threads;
    std::vector<mx_logger*> shared_results(thread_count, nullptr);

    for (int i = 0; i < thread_count; i++) {
        threads.emplace_back([i, &shared_results]() {
            if (i % 2 == 0) {
                auto* logger = mx_logger::initialize_namespace("mix_shared", CC_DIR,
                                                               nullptr, nullptr, nullptr, nullptr, nullptr);
                shared_results[i] = logger;
                logger->log(1, "mix", "hello", nullptr, false);
                mx_logger::global_for_loggerKey(logger->logger_key());
            } else {
                std::string ns = "mix_own_" + std::to_string(i);
                auto* logger = mx_logger::initialize_namespace(ns.c_str(), CC_DIR,
                                                               nullptr, nullptr, nullptr, nullptr, nullptr);
                shared_results[i] = logger;
                logger->log(1, "mix", "own", nullptr, false);
            }
        });
    }
    for (auto& t : threads) t.join();

    std::set<mx_logger*> shared_unique;
    for (int i = 0; i < thread_count; i += 2) shared_unique.insert(shared_results[i]);
    EXPECT_EQ(shared_unique.size(), (size_t)1);

    for (int i = 1; i < thread_count; i += 2) {
        EXPECT_TRUE(shared_results[i] != nullptr);
    }

    mx_logger::destroy();
}
