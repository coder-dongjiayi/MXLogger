//
//  test_support.hpp
//  MXLoggerCore 单元测试
//
//  日志文件解析相关的公共辅助函数
//

#ifndef test_support_hpp
#define test_support_hpp

#include <string>
#include <vector>
#include <map>
#include "mx_test.hpp"
#include "mxlogger_file_util.hpp"
#include "mxlogger_helper.hpp"

namespace mxtest {

using record_list = std::vector<std::map<std::string, std::string>>;

/// 找到目录下第一个.mx日志文件的完整路径
inline std::string first_mx_path(const std::string& dir) {
    record_list files;
    mxlogger::get_files(&files, dir.c_str());
    for (auto& f : files) {
        std::string n = f["name"];
        if (n.size() > 3 && n.substr(n.size() - 3) == ".mx") {
            return dir + n;
        }
    }
    return "";
}

/// 解析目录下第一个.mx文件的全部记录(含文件头记录)
inline record_list parse_dir(const std::string& dir,
                             const char* key = nullptr, const char* iv = nullptr) {
    record_list records;
    std::string path = first_mx_path(dir);
    if (!path.empty()) {
        mxlogger::select_form_path(path.c_str(), &records, key, iv);
    }
    return records;
}

/// 今天的日期前缀，对应 yyyy_MM_dd 策略生成的文件名
inline std::string today_prefix() {
    std::tm t = mxlogger_helper::now();
    char buf[16];
    snprintf(buf, sizeof(buf), "%04d-%02d-%02d", t.tm_year + 1900, t.tm_mon + 1, t.tm_mday);
    return buf;
}

}

#endif /* test_support_hpp */
