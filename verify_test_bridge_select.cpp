// 集成测试: 验证 flutter-bridge 的 select_logmsg / free_logmsg
// 写入(含AES加密) -> select_logmsg读回 -> 校验JSON内容 -> free_logmsg释放
// 需配合 AddressSanitizer 运行以捕获 use-after-free / 泄漏
#include <cstdio>
#include <cstring>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <filesystem>

extern "C" {
int64_t flutter_mxlogger_initialize(const char* ns, const char* directory,
                                    const char* storage_policy, const char* file_name,
                                    const char* file_header, const char* crypt_key,
                                    const char* iv);
int flutter_mxlogger_log(void* handle, const char* name, int lvl, const char* msg,
                         const char* tag);
char* flutter_mxlogger_get_diskcache_path(void* handle);
char* flutter_mxlogger_get_loggerKey(void* handle);
char* flutter_mxlogger_get_error_desc(void* handle);
void flutter_mxlogger_free_string(char* str);
int flutter_mxlogger_select_logmsg(const char* diskcache_file_path, const char* crypt_key,
                                   const char* iv, int* number, char*** array_ptr,
                                   uint32_t** size_array_ptr);
void flutter_mxlogger_free_logmsg(int number, char** array, uint32_t* size_array);
void flutter_mxlogger_destroy(const char* ns, const char* directory);
}

static int failures = 0;
#define CHECK(cond, desc)                                        \
    do {                                                         \
        if (cond) {                                              \
            printf("[PASS] %s\n", desc);                         \
        } else {                                                 \
            printf("[FAIL] %s (line %d)\n", desc, __LINE__);     \
            failures++;                                          \
        }                                                        \
    } while (0)

int main() {
    std::string dir = std::filesystem::temp_directory_path() / "mx_bridge_test";
    std::filesystem::remove_all(dir);
    std::filesystem::create_directories(dir);

    const char* kKey = "abcdefg123456789";  // 16字节
    const char* kIv = "1234567890abcdef";

    auto handle = (void*)flutter_mxlogger_initialize(
        "com.test.bridge", dir.c_str(), "yyyy_MM_dd", "bridgetest", nullptr, kKey, kIv);
    CHECK(handle != nullptr, "initialize");

    const int kCount = 50;
    int write_fail = 0;
    for (int i = 0; i < kCount; i++) {
        std::string msg = "message-" + std::to_string(i) + " 中文内容 \"quoted\"";
        if (flutter_mxlogger_log(handle, "testname", 1, msg.c_str(), "tagA,tagB") != 0)
            write_fail++;
    }
    CHECK(write_fail == 0, "write 50 encrypted logs");

    // get_loggerKey/get_diskcache_path 返回strdup拷贝 由free_string配对释放
    char* raw_path = flutter_mxlogger_get_diskcache_path(handle);
    CHECK(raw_path != nullptr && strlen(raw_path) > 0, "get_diskcache_path returns copy");
    std::string cache_path = raw_path;
    flutter_mxlogger_free_string(raw_path);

    char* logger_key = flutter_mxlogger_get_loggerKey(handle);
    CHECK(logger_key != nullptr && strlen(logger_key) == 32, "get_loggerKey returns md5 copy");
    flutter_mxlogger_free_string(logger_key);

    char* err_desc = flutter_mxlogger_get_error_desc(handle);
    flutter_mxlogger_free_string(err_desc);  // 可能为nullptr free(NULL)安全
    printf("[PASS] get_error_desc + free_string no crash\n");

    // 找到生成的.mx文件
    std::string log_file;
    for (auto& entry : std::filesystem::directory_iterator(cache_path)) {
        if (entry.path().extension() == ".mx") log_file = entry.path().string();
    }
    CHECK(!log_file.empty(), "log file exists");

    int number = -1;
    char** array = nullptr;
    uint32_t* size_array = nullptr;
    int r = flutter_mxlogger_select_logmsg(log_file.c_str(), kKey, kIv, &number, &array,
                                           &size_array);
    CHECK(r == 0, "select_logmsg returns 0");
    CHECK(number == kCount, "record count matches");
    CHECK(array != nullptr && size_array != nullptr, "out params filled");

    // 逐条校验内容(ASan下若指针悬垂会在此读取时崩溃)
    // select_logmsg返回倒序(最新在前, 与iOS端一致): 第i条应为 message-(count-1-i)
    bool content_ok = number == kCount;
    for (int i = 0; i < number && content_ok; i++) {
        std::string json(array[i], size_array[i]);
        std::string expected = "message-" + std::to_string(kCount - 1 - i);
        if (json.find("\"name\"") == std::string::npos ||
            json.find("testname") == std::string::npos ||
            json.find(expected) == std::string::npos ||
            json.find("\"error_code\":\"0\"") == std::string::npos) {
            printf("  record %d unexpected: %.120s\n", i, json.c_str());
            content_ok = false;
        }
    }
    CHECK(content_ok, "all records decrypt & parse correctly (newest-first)");

    flutter_mxlogger_free_logmsg(number, array, size_array);
    printf("[PASS] free_logmsg no crash\n");

    // 错误路径: 文件不存在
    int n2 = -1;
    char** a2 = nullptr;
    uint32_t* s2 = nullptr;
    int r2 = flutter_mxlogger_select_logmsg((dir + "/nope.mx").c_str(), kKey, kIv, &n2, &a2, &s2);
    CHECK(n2 == 0, "missing file: number is 0");
    (void)r2;

    // 错误key: 应返回error_code=1的记录而不是崩溃
    int n3 = -1;
    char** a3 = nullptr;
    uint32_t* s3 = nullptr;
    int r3 = flutter_mxlogger_select_logmsg(log_file.c_str(), "0000000000000000", kIv, &n3, &a3, &s3);
    CHECK(r3 == 0 && n3 == kCount, "wrong key: still returns records");
    bool marked = n3 > 0 && std::string(a3[0], s3[0]).find("\"error_code\":\"1\"") != std::string::npos;
    CHECK(marked, "wrong key: records marked error_code=1");
    flutter_mxlogger_free_logmsg(n3, a3, s3);

    flutter_mxlogger_destroy("com.test.bridge", dir.c_str());
    std::filesystem::remove_all(dir);

    printf("\n%s (%d failures)\n", failures == 0 ? "ALL PASS" : "FAILED", failures);
    return failures == 0 ? 0 : 1;
}
