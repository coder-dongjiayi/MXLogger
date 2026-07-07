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
#include <sys/stat.h>

#include <dirent.h>
#include <sys/file.h>
#include <unistd.h>
#include <cerrno>
#include <cstring>
#include "log_serialize.h"
#include "mxlogger_helper.hpp"
#include "aes/aes_crypt.hpp"
#include "debug_log.hpp"
namespace mxlogger{
inline size_t file_size(const char* path){
    struct stat statbuf;
    lstat(path, &statbuf);
    return statbuf.st_size;
}

inline bool path_exists(const char*  path){
    struct stat buffer;
    return (::stat(path, &buffer) == 0);
}

//使用0777 作为文件夹权限，用于日志文件导出。
inline bool makedir(const char* path){
    
    return ::mkdir(path,mode_t(0777)) == 0;
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
    int fd =  open(path, O_RDONLY|O_CLOEXEC);
    if (fd < 0) {
        MXLoggerError("select_form_path: open failed %s",strerror(errno));
        return -1;
    }

    /// 以磁盘真实大小为边界，防止损坏的size字段导致越界读取
    size_t disk_size = file_size(path);

    uint32_t size = 0;
    if (read(fd, &size, sizeof(uint32_t)) != (ssize_t)sizeof(uint32_t)) {
        close(fd);
        return -1;
    }

    size_t begin = sizeof(uint32_t);
    while (begin <= size && begin + sizeof(uint32_t) <= disk_size) {

        uint32_t  item_size = 0;

        if (read(fd, &item_size, sizeof(uint32_t)) != (ssize_t)sizeof(uint32_t)) break;

        /// 记录头损坏(长度为0或超出文件边界)，终止解析
        if (item_size == 0 || begin + sizeof(uint32_t) + item_size > disk_size) break;

        std::vector<uint8_t> buffer(item_size);

        if (read(fd, buffer.data(), item_size) != (ssize_t)item_size) break;

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

    close(fd);

    return 0;
}



inline int get_files(std::vector<std::map<std::string, std::string>> *destination,const char * dir_){
    int result = 0;
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
    std::sort(destination->begin(), destination->end(), [](std::map<std::string, std::string> &a,std::map<std::string, std::string> &b){
        std::string a_time = a["create_timestamp"];
        long a_t = std::stol(a_time);
        
        std::string b_time = b["create_timestamp"];
        long b_t = std::stol(b_time);
        return a_t > b_t;
    });
    closedir(dir);

    return result;
}



}





#endif /* mxlogger_file_util_hpp */
