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
#include <sys/stat.h>
#include <fstream>

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

inline size_t  select_form(std::vector<std::string> *vector,const char* path,size_t begin, int limit){
    
   
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
    printf("begin = %zu \n",begin);
    while (number < limit && std::getline(in_file, line)) {
        
        bytes = bytes + line.size() + 1;
        vector ->push_back(line.data());
        number ++ ;
    }
  
    
    
    return bytes;
}





}





#endif /* mxlogger_file_util_hpp */
