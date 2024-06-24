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
#include "log_serialize.h"
#include "mxlogger_helper.hpp"
#include "aes/aes_crypt.hpp"
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
        printf("文件路径不存在\n");
        return  -1;
    }


    aes_crypt  crypt;
    const char* iv_ = iv;
    if (crypt_key != nullptr) {

        crypt.set_crypt_key(crypt_key, strlen(crypt_key), (void*)iv_, strlen(iv_));
    }


    int fd =  open(path, O_RDWR|O_CLOEXEC|O_CREAT,S_IRWXU);

    uint32_t size;
    read(fd, &size, sizeof(uint32_t));

    size_t begin = sizeof(uint32_t);
    while (begin <= size) {

        uint32_t  item_size;

        read(fd, &item_size, sizeof(uint32_t));
            
       
        uint8_t * buffer = (uint8_t*)malloc(item_size);

        read(fd, buffer , item_size);

        if (crypt_key != nullptr) {

            crypt.decrypt(buffer, buffer, item_size);

            crypt.reset_iv(iv_,strlen(iv_));
        }
        
        flatbuffers::Verifier verifier(buffer,item_size);

        bool isBuffer =  Verifylog_serializeBuffer(verifier);
        std::map<std::string, std::string> map;
        
        if(isBuffer == true){
            auto logger =  Getlog_serialize(buffer);
            map["error_code"] = "0";
            map["msg"] = logger->msg() == nullptr ? "" : logger->msg()->str();
            map["tag"] = logger->tag() == nullptr ? "" : logger->tag()->str();
            map["name"] = logger->name()->c_str();
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

        free(buffer);

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
        char subdir[256];
        sprintf(subdir, "%s%s", dir_, entry->d_name);
       
        lstat(subdir, &statbuf);
        
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
