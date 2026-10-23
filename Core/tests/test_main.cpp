//
//  test_main.cpp
//  MXLoggerCore 单元测试入口
//

#include "mx_test.hpp"
#include <cstdlib>
#include "mxlogger_interprocess.hpp"
#if MXLOGGER_MACOS_MULTIPROCESS
#include <csignal>
int mxlogger_process_worker(int argc, char **argv);
#endif

int main(int argc, char **argv) {
#if MXLOGGER_MACOS_MULTIPROCESS
    std::signal(SIGPIPE, SIG_IGN); // Report worker failures instead of terminating the test runner.
    if (argc > 1 && strcmp(argv[1], "--ipc-worker") == 0) {
        return mxlogger_process_worker(argc, argv);
    }
#endif
    // 每次运行使用干净的临时目录，跑完保留现场便于排查
    system("rm -rf mxtest_tmp && mkdir -p mxtest_tmp");
    return mxtest::run_all();
}
