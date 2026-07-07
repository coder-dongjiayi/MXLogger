//
//  mxlogger_file_util.hpp
//  mxlogger_file_util
//
//  Created by 董家祎 on 2022/4/29.
//

#ifndef mxlogger_file_util_hpp
#define mxlogger_file_util_hpp

#include <stdio.h>
#include <string>
#include <vector>
#include <map>
#include <algorithm>
#include <cerrno>
#include <cstring>
#include <sys/stat.h>

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <direct.h>
#include <fcntl.h>
#else
#include <dirent.h>
#include <sys/file.h>
#include <unistd.h>
#include <fcntl.h>
#endif

#include "log_serialize.h"
#include "mxlogger_helper.hpp"
#include "aes/aes_crypt.hpp"
#include "debug_log.hpp"
namespace mxlogger{

#ifdef _WIN32
/// Windows文件API需要宽字符才能正确处理中文等非ASCII路径
inline std::wstring utf8_to_wide(const char* utf8){
    if (utf8 == nullptr) return L"";
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, nullptr, 0);
    if (len <= 1) return L"";
    std::wstring wide((size_t)len - 1, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, &wide[0], len);
    return wide;
}

inline std::string wide_to_utf8(const wchar_t* wide){
    if (wide == nullptr) return "";
    int len = WideCharToMultiByte(CP_UTF8, 0, wide, -1, nullptr, 0, nullptr, nullptr);
    if (len <= 1) return "";
    std::string utf8((size_t)len - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wide, -1, &utf8[0], len, nullptr, nullptr);
    return utf8;
}

/// FILETIME(1601年起的100ns计数) 转 unix秒
inline long filetime_to_unix(const FILETIME& ft){
    ULARGE_INTEGER u;
    u.LowPart = ft.dwLowDateTime;
    u.HighPart = ft.dwHighDateTime;
    return (long)((u.QuadPart - 116444736000000000ULL) / 10000000ULL);
}
#endif

inline size_t file_size(const char* path){
#ifdef _WIN32
    struct _stat64 statbuf;
    if (::_wstat64(utf8_to_wide(path).c_str(), &statbuf) != 0) {
        return 0;
    }
    return (size_t)statbuf.st_size;
#else
    struct stat statbuf;
    if (lstat(path, &statbuf) != 0) {
        return 0;
    }
    return statbuf.st_size;
#endif
}

inline bool path_exists(const char*  path){
#ifdef _WIN32
    return GetFileAttributesW(utf8_to_wide(path).c_str()) != INVALID_FILE_ATTRIBUTES;
#else
    struct stat buffer;
    return (::stat(path, &buffer) == 0);
#endif
}

//使用0777 作为文件夹权限，用于日志文件导出。
inline bool makedir(const char* path){
#ifdef _WIN32
    return ::_wmkdir(utf8_to_wide(path).c_str()) == 0;
#else
    return ::mkdir(path,mode_t(0777)) == 0;
#endif
}


inline bool create_dir(const std::string &path){

    auto pos = path.find_last_of("/");

    std::string dir_name = pos != std::string::npos ? path.substr(0,pos) : std::string{};


    if (path_exists(dir_name.data()))  return  true;

    if (dir_name.empty())  return  false;

    size_t search_offset = 0;
    do {
       auto token_pos =  dir_name.find_first_of("/",search_offset);
        if (token_pos == std::string::npos) {
            token_pos = dir_name.size();
        }
        auto subdir = dir_name.substr(0,token_pos);
        if (!subdir.empty() && !path_exists(subdir.data()) && !makedir(subdir.data())) {

            return  false;

        }
        search_offset = token_pos + 1;

    } while (search_offset < dir_name.size());


    return true;
}

/// 只读打开文件，返回文件描述符，失败返回-1
inline int open_readonly_(const char* path){
#ifdef _WIN32
    return ::_wopen(utf8_to_wide(path).c_str(), _O_RDONLY | _O_BINARY | _O_NOINHERIT);
#else
    return ::open(path, O_RDONLY|O_CLOEXEC);
#endif
}

inline long read_(int fd, void* buffer, size_t size){
#ifdef _WIN32
    return (long)::_read(fd, buffer, (unsigned int)size);
#else
    return (long)::read(fd, buffer, size);
#endif
}

inline void close_(int fd){
#ifdef _WIN32
    ::_close(fd);
#else
    ::close(fd);
#endif
}

inline int  select_form_path(const char* path,std::vector<std::map<std::string, std::string>> *vector,const char* crypt_key, const char* iv){



    if (path_exists(path) == false) {
        MXLoggerError("select_form_path: file not exists %s",path);
        return  -1;
    }

    bool is_crypt = crypt_key != nullptr && strlen(crypt_key) > 0;

    aes_crypt  crypt;
    // iv补零到16字节，与写入端对齐；每条记录解密后必须用完整16字节恢复向量
    size_t iv_length = iv == nullptr ? 0 : strlen(iv);
    uint8_t iv_[AES_KEY_LEN] = {};
    if (iv_length > 0) {
        memcpy(iv_, iv, iv_length > AES_KEY_LEN ? AES_KEY_LEN : iv_length);
    }
    if (is_crypt) {

        crypt.set_crypt_key(crypt_key, strlen(crypt_key), iv_length > 0 ? (void*)iv_ : nullptr, iv_length > 0 ? AES_KEY_LEN : 0);
    }

    /// 只读解析，不应创建/写入文件
    int fd = open_readonly_(path);
    if (fd < 0) {
        MXLoggerError("select_form_path: open failed %s",strerror(errno));
        return -1;
    }

    /// 以磁盘真实大小为边界，防止损坏的size字段导致越界读取
    size_t disk_size = file_size(path);

    uint32_t size = 0;
    if (read_(fd, &size, sizeof(uint32_t)) != (long)sizeof(uint32_t)) {
        close_(fd);
        return -1;
    }

    size_t begin = sizeof(uint32_t);
    while (begin <= size && begin + sizeof(uint32_t) <= disk_size) {

        uint32_t  item_size = 0;

        if (read_(fd, &item_size, sizeof(uint32_t)) != (long)sizeof(uint32_t)) break;

        /// 记录头损坏(长度为0或超出文件边界)，终止解析
        if (item_size == 0 || begin + sizeof(uint32_t) + item_size > disk_size) break;

        std::vector<uint8_t> buffer(item_size);

        if (read_(fd, buffer.data(), item_size) != (long)item_size) break;

        if (is_crypt) {

            crypt.decrypt(buffer.data(), buffer.data(), item_size);

            crypt.reset_iv(iv_length > 0 ? iv_ : nullptr, iv_length > 0 ? AES_KEY_LEN : 0);
        }

        flatbuffers::Verifier verifier(buffer.data(),item_size);

        bool isBuffer =  Verifylog_serializeBuffer(verifier);
        std::map<std::string, std::string> map;

        if(isBuffer == true){
            auto logger =  Getlog_serialize(buffer.data());
            map["error_code"] = "0";
            map["msg"] = logger->msg() == nullptr ? "" : logger->msg()->str();
            map["tag"] = logger->tag() == nullptr ? "" : logger->tag()->str();
            map["name"] = logger->name() == nullptr ? "" : logger->name()->str();
            map["timestamp"] = std::to_string(logger->timestamp());
            map["level"] = std::to_string(logger->level());
            map["is_main_thread"] =std::to_string(logger->is_main_thread());
            map["thread_id"] = std::to_string(logger->thread_id());
        }else{
            map["error_code"] = "1";
            map["msg"] = "数据异常,可能原因(加密用的key 和 iv 不一致)";
        }

        vector->push_back(map);

        begin = begin + sizeof(uint32_t) + item_size;

    }

    close_(fd);

    return 0;
}



inline int get_files(std::vector<std::map<std::string, std::string>> *destination,const char * dir_){
    int result = 0;

#ifdef _WIN32
    std::wstring pattern = utf8_to_wide(dir_) + L"*";
    WIN32_FIND_DATAW find_data;
    HANDLE find_handle = FindFirstFileW(pattern.c_str(), &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) {

        fprintf(stderr, "Cannot open dir: %s\n", dir_);
        return -1;
    }

    do {
        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            continue;
        }
        std::string name = wide_to_utf8(find_data.cFileName);
        if (name == ".DS_Store") {
            continue;
        }

        long long st_size = ((long long)find_data.nFileSizeHigh << 32) | find_data.nFileSizeLow;
        long last_time = filetime_to_unix(find_data.ftLastWriteTime);
        long create_time = filetime_to_unix(find_data.ftCreationTime);

        std::map<std::string, std::string> map;
        map["name"] = name;
        map["last_timestamp"] = std::to_string(last_time);
        map["create_timestamp"] = std::to_string(create_time);
        map["size"] = std::to_string(st_size);

        destination->push_back(map);

    } while (FindNextFileW(find_handle, &find_data));

    FindClose(find_handle);
#else
    DIR *dir;
    struct stat statbuf;

    struct dirent *entry;

    if ((dir = opendir(dir_)) == nullptr){

        fprintf(stderr, "Cannot open dir: %s\n", dir_);
        return -1;
    }

    while ((entry = readdir(dir)) != nullptr) {

        if (strcmp(".DS_Store", entry->d_name) == 0 || strcmp(".", entry->d_name) == 0 || strcmp("..", entry->d_name) == 0) {
            continue;
        }
        std::string subdir = std::string(dir_) + entry->d_name;

        lstat(subdir.c_str(), &statbuf);

        long last_time = (long)statbuf.st_mtime;
        long st_size =  (long)statbuf.st_size;

#ifdef __ANDROID__
        long create_time = (long)statbuf.st_atime;
#elif __APPLE__
        long create_time = (long)statbuf.st_birthtime;
#else
        /// Linux的stat没有创建时间，用mtime近似(仅影响清理时的新旧排序)
        long create_time = (long)statbuf.st_mtime;
#endif


        std::map<std::string, std::string> map;

        std::string name = entry->d_name;
        std::string lasttime =  std::to_string(last_time);
        std::string size =  std::to_string(st_size);
        std::string createtime =  std::to_string(create_time);
        map["name"] = name;
        map["last_timestamp"] = lasttime;
        map["create_timestamp"] = createtime;
        map["size"] = size;

        destination->push_back(map);

    }
    closedir(dir);
#endif

    std::sort(destination->begin(), destination->end(), [](std::map<std::string, std::string> &a,std::map<std::string, std::string> &b){
        std::string a_time = a["create_timestamp"];
        long a_t = std::stol(a_time);

        std::string b_time = b["create_timestamp"];
        long b_t = std::stol(b_time);
        return a_t > b_t;
    });

    return result;
}



}





#endif /* mxlogger_file_util_hpp */
