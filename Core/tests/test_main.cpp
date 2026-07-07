//
//  test_main.cpp
//  MXLoggerCore 单元测试入口
//

#include "mx_test.hpp"
#include <cstdlib>

int main() {
    // 每次运行使用干净的临时目录，跑完保留现场便于排查
    system("rm -rf mxtest_tmp && mkdir -p mxtest_tmp");
    return mxtest::run_all();
}
