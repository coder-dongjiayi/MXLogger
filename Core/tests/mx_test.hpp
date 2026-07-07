//
//  mx_test.hpp
//  MXLoggerCore 单元测试框架
//
//  轻量自注册测试框架，无外部依赖，与工程风格保持一致。
//  用法:
//    MX_TEST(suite_name, case_name) { EXPECT_EQ(a, b); EXPECT_TRUE(x); }
//

#ifndef mx_test_hpp
#define mx_test_hpp

#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <ctime>
#include <string>
#include <sstream>
#include <vector>
#include <map>
#include <sys/time.h>

namespace mxtest {

struct test_case {
    const char* suite;
    const char* name;
    void (*fn)();
};

inline std::vector<test_case>& registry() {
    static std::vector<test_case> r;
    return r;
}

struct registrar {
    registrar(const char* suite, const char* name, void (*fn)()) {
        registry().push_back({suite, name, fn});
    }
};

inline int g_checks = 0;
inline int g_failures = 0;

inline void report(bool ok, const char* expr, const char* file, int line, const std::string& detail = "") {
    g_checks++;
    if (!ok) {
        g_failures++;
        printf("    ✗ FAIL %s:%d  %s%s\n", file, line, expr, detail.c_str());
    }
}

template <typename A, typename B>
inline void expect_eq(const A& a, const B& b, const char* expr, const char* file, int line) {
    bool ok = (a == b);
    std::string detail;
    if (!ok) {
        std::ostringstream oss;
        oss << "  (actual: [" << a << "] vs [" << b << "])";
        detail = oss.str();
    }
    report(ok, expr, file, line, detail);
}

inline int run_all() {
    int failed_cases = 0;
    const char* last_suite = "";
    for (auto& t : registry()) {
        if (strcmp(last_suite, t.suite) != 0) {
            printf("\n[%s]\n", t.suite);
            last_suite = t.suite;
        }
        int before = g_failures;
        t.fn();
        printf("  %s %s\n", g_failures == before ? "PASS" : "FAIL", t.name);
        if (g_failures != before) failed_cases++;
    }
    printf("\n========================================\n");
    printf("%zu cases, %d checks, %d check failures, %d failed cases\n",
           registry().size(), g_checks, g_failures, failed_cases);
    printf(failed_cases == 0 ? "ALL PASSED\n" : "FAILED\n");
    return failed_cases == 0 ? 0 : 1;
}

// ---------- 文件系统辅助 ----------

/// 创建一个干净的测试临时目录(带尾部/)，每个用例用自己的目录保证隔离
inline std::string temp_dir(const std::string& name) {
    std::string dir = "mxtest_tmp/" + name + "/";
    std::string cmd = "rm -rf " + dir + " && mkdir -p " + dir;
    system(cmd.c_str());
    return dir;
}

inline void write_dummy_file(const std::string& path, size_t size, char fill = 'x') {
    FILE* fp = fopen(path.c_str(), "wb");
    if (!fp) return;
    std::string data(size, fill);
    fwrite(data.data(), 1, size, fp);
    fclose(fp);
}

/// 读整个文件(二进制安全)
inline std::string slurp(const std::string& path) {
    FILE* fp = fopen(path.c_str(), "rb");
    if (!fp) return "";
    fseek(fp, 0, SEEK_END);
    long n = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    std::string s((size_t)n, '\0');
    fread(&s[0], 1, (size_t)n, fp);
    fclose(fp);
    return s;
}

inline bool contains_bytes(const std::string& haystack, const std::string& needle) {
    return haystack.find(needle) != std::string::npos;
}

/// 把文件修改时间改到 N 天前，用于测试过期清理
inline void set_mtime_days_ago(const std::string& path, int days) {
    struct timeval tv[2];
    time_t t = time(nullptr) - (time_t)days * 86400;
    tv[0].tv_sec = t; tv[0].tv_usec = 0;
    tv[1].tv_sec = t; tv[1].tv_usec = 0;
    utimes(path.c_str(), tv);
}

}

#define MX_TEST(suite, name)                                                        \
    static void mx_test_##suite##_##name();                                         \
    static mxtest::registrar mx_reg_##suite##_##name(#suite, #name,                 \
                                                     &mx_test_##suite##_##name);    \
    static void mx_test_##suite##_##name()

#define EXPECT_TRUE(x)  mxtest::report(!!(x), #x, __FILE__, __LINE__)
#define EXPECT_FALSE(x) mxtest::report(!(x), "!(" #x ")", __FILE__, __LINE__)
#define EXPECT_EQ(a, b) mxtest::expect_eq((a), (b), #a " == " #b, __FILE__, __LINE__)

#endif /* mx_test_hpp */
