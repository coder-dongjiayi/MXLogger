//
//  test_main.cpp
//  MXLoggerCore 单元测试入口
//

#include "mx_test.hpp"
#include <cstdlib>
#include "mxlogger_interprocess.hpp"
#if MXLOGGER_MULTIPROCESS
#include <csignal>
int mxlogger_process_worker(int argc, char **argv);
#endif

static int run_main(int argc, char **argv) {
#if MXLOGGER_MULTIPROCESS
    #ifndef _WIN32
    std::signal(SIGPIPE, SIG_IGN); // Report worker failures instead of terminating the test runner.
    #endif
    if (argc > 1 && strcmp(argv[1], "--ipc-worker") == 0) {
        return mxlogger_process_worker(argc, argv);
    }
#endif
    // 每次运行使用干净的临时目录，跑完保留现场便于排查
    if (!mxtest::reset_dir("mxtest_tmp")) return 1;
#if !MXLOGGER_MULTIPROCESS
    printf("[SKIP] multiprocess tests require native macOS or Windows\n");
#endif
    return mxtest::run_all();
}

#ifdef _WIN32
int wmain(int argc, wchar_t **wide_argv) {
    std::vector<std::string> values;
    for (int i = 0; i < argc; ++i) values.push_back(mxlogger::files::to_utf8(wide_argv[i]));
    std::vector<char *> argv;
    for (auto &value : values) argv.push_back(&value[0]);
    argv.push_back(nullptr);
    return run_main(argc, argv.data());
}
#else
int main(int argc, char **argv) { return run_main(argc, argv); }
#endif
