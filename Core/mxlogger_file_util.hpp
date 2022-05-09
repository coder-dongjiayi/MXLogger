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
#include <fstream>
#include <dirent.h>
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
    
    return ::mkdir(path,mode_t(0755)) == 0;
}

inline size_t  select_form_path(const char* path,std::vector<std::string> *vector,size_t begin, int limit){
    
   
    if (path_exists(path) == false) {
        printf("文件路径不存在\n");
        return  -1;
    }
    
    std::ifstream in_file(path,std::ios::in | std::ios::binary);
   
    if (!in_file) {
        printf("文件打开失败\n");
        return -2;
    }
  
    in_file.seekg(begin);
    
    std::string line;
    
    size_t bytes = 0;
    
    int number = 0;

    while (number < limit && std::getline(in_file, line)) {
        
        bytes = bytes + line.size() + 1;
        vector ->push_back(line.data());
        number ++ ;
    }
  
    
    
    return bytes;
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
        
        long last_time = (long)statbuf.st_ctime;
        long st_size =  (long)statbuf.st_size;
        
        std::map<std::string, std::string> map;
        
        std::string name = entry->d_name;
        std::string time =  std::to_string(last_time);
        std::string size =  std::to_string(st_size);
        
        map["name"] = name;
        map["timestamp"] = time;
        map["size"] = size;
        
        destination->push_back(map);
      
    }
    std::sort(destination->begin(), destination->end(), [](std::map<std::string, std::string> &a,std::map<std::string, std::string> &b){
        std::string a_time = a["timestamp"];
        long a_t = std::stol(a_time);
        
        std::string b_time = b["timestamp"];
        long b_t = std::stol(b_time);
        return a_t > b_t;
    });
    closedir(dir);

    return result;
}



}





#endif /* mxlogger_file_util_hpp */
