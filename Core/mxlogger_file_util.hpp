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
#include <cstdint>
#include <sys/stat.h>
#include "mxlogger_file.hpp"

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <direct.h>
#include <fcntl.h>
#include <filesystem>
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
#include "mxlogger_interprocess.hpp"
namespace mxlogger{

#ifdef _WIN32
/// Windows文件API需要宽字符才能正确处理中文等非ASCII路径
inline std::wstring utf8_to_wide(const char* utf8){
    return files::to_wide(utf8);
}

inline std::string wide_to_utf8(const wchar_t* wide){
    return files::to_utf8(wide);
}

/// FILETIME(1601年起的100ns计数) 转 unix秒
inline int64_t filetime_to_unix(const FILETIME& ft){
    ULARGE_INTEGER u;
    u.LowPart = ft.dwLowDateTime;
    u.HighPart = ft.dwHighDateTime;
    return (static_cast<int64_t>(u.QuadPart) - 116444736000000000LL) / 10000000LL;
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
#ifdef _WIN32
    // Construct from UTF-16: narrow filesystem paths use the Windows code page.
    // parent_path handles drive roots, both separators and UNC shares.
    const std::wstring wide = utf8_to_wide(path.c_str());
    if (wide.empty()) { errno = EINVAL; return false; }
    const auto parent = std::filesystem::path(wide).parent_path();
    if (parent.empty()) { errno = EINVAL; return false; }
    std::error_code error;
    std::filesystem::create_directories(parent, error);
    if (error) {
        errno = error == std::errc::permission_denied ? EACCES : EIO;
        return false;
    }
    return std::filesystem::is_directory(parent, error) && !error;
#else
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
#if MXLOGGER_MULTIPROCESS
            // Another process may have created this component after our stat.
            if (errno == EEXIST && path_exists(subdir.c_str())) {
                search_offset = token_pos + 1;
                continue;
            }
#endif
            return  false;

        }
        search_offset = token_pos + 1;

    } while (search_offset < dir_name.size());


    return true;
#endif
}

inline int remove_file(const char* path) {
#ifdef _WIN32
    return ::_wremove(utf8_to_wide(path).c_str());
#else
    return ::remove(path);
#endif
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
#if MXLOGGER_MULTIPROCESS
    std::vector<uint8_t> snapshot;
    if (!ipc::read_snapshot(path, snapshot)) return -1;
    size_t disk_size = snapshot.size();
    size_t cursor = 0;
    auto read_record = [&](void *buffer, size_t bytes) -> long {
        size_t available = std::min(bytes, snapshot.size() - cursor);
        memcpy(buffer, snapshot.data() + cursor, available);
        cursor += available;
        return static_cast<long>(available);
    };
#else
    int fd = open_readonly_(path);
    if (fd < 0) {
        MXLoggerError("select_form_path: open failed %s",strerror(errno));
        return -1;
    }

    /// 以磁盘真实大小为边界，防止损坏的size字段导致越界读取
    size_t disk_size = file_size(path);
#endif

    uint32_t size = 0;
#if MXLOGGER_MULTIPROCESS
    if (read_record(&size, sizeof(uint32_t)) != sizeof(uint32_t)) return -1;
#else
    if (read_(fd, &size, sizeof(uint32_t)) != (long)sizeof(uint32_t)) {
        close_(fd);
        return -1;
    }
#endif

    size_t begin = sizeof(uint32_t);
    while (begin <= size && begin + sizeof(uint32_t) <= disk_size) {

        uint32_t  item_size = 0;

#if MXLOGGER_MULTIPROCESS
        if (read_record(&item_size, sizeof(uint32_t)) != sizeof(uint32_t)) break;
#else
        if (read_(fd, &item_size, sizeof(uint32_t)) != (long)sizeof(uint32_t)) break;
#endif

        /// 记录头损坏(长度为0或超出文件边界)，终止解析
        if (item_size == 0 || begin + sizeof(uint32_t) + item_size > disk_size) break;

        std::vector<uint8_t> buffer(item_size);

#if MXLOGGER_MULTIPROCESS
        if (read_record(buffer.data(), item_size) != item_size) break;
#else
        if (read_(fd, buffer.data(), item_size) != (long)item_size) break;
#endif

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

#if !MXLOGGER_MULTIPROCESS
    close_(fd);
#endif

    return 0;
}



inline int get_files(std::vector<std::map<std::string, std::string>> *destination,const char * dir_){
    int result = 0;

#ifdef _WIN32
    std::wstring pattern = utf8_to_wide(dir_);
    if (pattern.empty()) return -1;
    if (pattern.back() != L'/' && pattern.back() != L'\\') pattern += L'\\';
    pattern += L'*';
    WIN32_FIND_DATAW find_data;
    HANDLE find_handle = FindFirstFileW(pattern.c_str(), &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) {

        fprintf(stderr, "Cannot open dir: %s\n", dir_);
        return -1;
    }

    do {
        if (find_data.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) {
            continue;
        }
        std::string name = wide_to_utf8(find_data.cFileName);
        if (CompareStringOrdinal(find_data.cFileName, -1, L".mxlogger.lock", -1, TRUE) == CSTR_EQUAL) continue;
        if (name == ".DS_Store") {
            continue;
        }

        long long st_size = ((long long)find_data.nFileSizeHigh << 32) | find_data.nFileSizeLow;
        int64_t last_time = filetime_to_unix(find_data.ftLastWriteTime);
        int64_t create_time = filetime_to_unix(find_data.ftCreationTime);

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
#if MXLOGGER_MULTIPROCESS
        // The coordinator is neither a log nor part of the age/size budget.
        if (strcmp(ipc::lock_filename, entry->d_name) == 0) continue;
#endif
        std::string subdir = std::string(dir_) + entry->d_name;

        /// lstat失败(文件在readdir后被删除)则跳过，防止读到未初始化的statbuf
        /// Skip on lstat failure (the file was removed after readdir) to avoid
        /// reading an uninitialized statbuf
        if (lstat(subdir.c_str(), &statbuf) != 0) {
            continue;
        }
        /// 只统计常规文件：与Windows分支行为对齐，跳过子目录/符号链接等，
        /// 否则目录会被当成日志文件计入大小、进入列表甚至被清理逻辑删除
        /// Regular files only — consistent with the Windows branch. Without this,
        /// subdirectories are treated as log files: counted into dir_size, listed,
        /// and even deleted by the cleanup logic
        if (!S_ISREG(statbuf.st_mode)) {
            continue;
        }

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
        int64_t a_t = std::stoll(a_time);

        std::string b_time = b["create_timestamp"];
        int64_t b_t = std::stoll(b_time);
        return a_t > b_t;
    });

    return result;
}



}





#endif /* mxlogger_file_util_hpp */
