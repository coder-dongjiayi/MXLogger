//
//  base_file_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/8.
//

#include "base_file_sink.hpp"
#include <map>
#include "mxlogger_helper.hpp"
#include "mxlogger_file_util.hpp"
namespace mxlogger{
namespace sinks{
// 文件最大存储时间 默认为0 不限制
void base_file_sink::set_max_disk_age(long long max_age){
    max_disk_age_ = max_age;
}

// 文件最大存储大小 默认为0 不限制
void base_file_sink::set_max_disk_size(long long max_size){
    max_disk_size_ = max_size;
}
void base_file_sink::set_dir(const std::string &dir_path){
    dir_path_ = dir_path;
}
long  base_file_sink::dir_size() const{
   
    long   current_cache_size=0;
    
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_path_.c_str());
    
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        current_cache_size  = current_cache_size + std::stol(map["size"]);
        
    }
    
    return  current_cache_size;
    
  
}

// 删除过期文件
void base_file_sink::remove_expire_data(){
    
     long   current_cache_size=0;
   
     std::vector<std::string> delete_urls;
     std::vector<std::map<std::string, std::string>> final_dir;
     
     std::tm tm_time = mxlogger_helper::now();
     
     long long int timestamp =  mktime(&tm_time);
     long long int expiration_tp = timestamp - max_disk_age_;
     
     std::vector<std::map<std::string, std::string>> destination;
  
     if(max_disk_age_ > 0){
         mxlogger::get_files(&destination, dir_path_.c_str());
         // step1 遍历文件找出过期文件，统计文件size
         for (int i = 0; i < destination.size(); i++) {
             std::map<std::string, std::string> map = destination[i];
             std::string file_name  = map["name"];
             long size = std::stol(map["size"]);
             time_t last_time = (time_t)std::stol(map["timestamp"]);
             
             if (last_time < expiration_tp) {
                 /// 过期文件
                 delete_urls.push_back(file_name);
                
                 continue;
             }else{
                 final_dir.push_back(map);
             }
             current_cache_size = current_cache_size + size;
            
         }
         //删除过期文件
         for (int i = 0; i< delete_urls.size(); i++) {
             char delete_path[256];
             
             std::string name = delete_urls[i];
             
             sprintf(delete_path, "%s%s", dir_path_.c_str(), name.c_str());
             if (remove(delete_path) != 0) {
                 printf("删除文件失败");
             }
             
         }
     }
    
    
   // step2 清理大于目标size的文件
     if (max_disk_size_ > 0 && current_cache_size > max_disk_size_) {
         for (int i = 0; i < final_dir.size(); i++) {
             std::map<std::string, std::string> map = final_dir[i];
             std::string file_name  = map["name"];
             long file_size = std::stol(map["size"]);
             char delete_path[256];
             
             sprintf(delete_path, "%s%s", dir_path_.c_str(), file_name.c_str());
             if (remove(delete_path) == 0) {
                 current_cache_size = current_cache_size - file_size;
            
                 if (max_disk_size_ >= current_cache_size) {
                     break;
                 }
             }
         }
     }
     
    
}

// 删除所有日志文件
void base_file_sink::remove_all(){
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_path_.c_str());
    
    
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        std::string file_name  = map["name"];
        char subdir[256];
        sprintf(subdir, "%s%s", dir_path_.c_str(), file_name.c_str());
        remove(subdir);
    }
}
}
}

