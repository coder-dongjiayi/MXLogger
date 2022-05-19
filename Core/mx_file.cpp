//
//  file_helper.cpp
//  Logger
//
//  Created by 董家祎 on 2022/3/4.
//

#include "mx_file.hpp"
#include <sys/stat.h>
#include <thread>
#include <dirent.h>
#include <vector>
#include <stdio.h>
#include "mxlogger_helper.hpp"
#include <map>
#ifdef  __ANDROID__
#include <android/log.h>
#endif
#include "mxlogger_file_util.hpp"

namespace mxlogger{
namespace details{

mx_file::mx_file() : max_disk_size_(0),max_disk_age_(0){

}

mx_file::~mx_file(){
  
    close();
}


void mx_file::set_max_disk_age(long long max_age){
    max_disk_age_ = max_age;
}


void mx_file::set_max_disk_size(long long max_size){
    max_disk_size_ = max_size;
}

void mx_file::open(){
    close();
    
    std::string mode = "ab";

    for (int tries = 0; tries < open_tries_; tries ++ ) {
        create_dir_(dir_);
        
        auto filepath = dir_ + filename_;
      
       fd_ =  fopen(filepath.c_str(), mode.c_str());
        if (fd_ != nullptr) {
          
            if (header_buffer_.data() != nullptr && strcmp(header_buffer_.data(), "")!=0) {
                struct stat statbuf;
                
                lstat(filepath.c_str(), &statbuf);
                // 保证只在首次创建文件的时候写入
                if (statbuf.st_size == 0) {
                    write(header_buffer_, filename_);
                }
                
                
            }
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
}

std::string &mx_file::filename() {
    return filename_ ;
}

void mx_file::flush(){
    std::fflush(fd_);
}
void mx_file::close(){
    if (fd_ != nullptr) {
        std::fclose(fd_);
        fd_ = nullptr;
    }
}
long  mx_file::dir_size() const{
   
    long   current_cache_size=0;
    
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_.c_str());
    
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        current_cache_size  = current_cache_size + std::stol(map["size"]);
        
    }
    
    return  current_cache_size;
    
  
}
void mx_file::remove_all(){
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_.c_str());
    
    
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        std::string file_name  = map["name"];
        char subdir[256];
        sprintf(subdir, "%s%s", dir_.c_str(), file_name.c_str());
        remove(subdir);
    }
    
}

void mx_file::remove_expire_data(){
   

   
    long   current_cache_size=0;
  
    std::vector<std::string> delete_urls;
    std::vector<std::map<std::string, std::string>> final_dir;
    
    std::tm tm_time = mxlogger_helper::now();
    
    long long int timestamp =  mktime(&tm_time);
    long long int expiration_tp = timestamp - max_disk_age_;
    
    std::vector<std::map<std::string, std::string>> destination;
 
    if(max_disk_age_ > 0){
        mxlogger::get_files(&destination, dir_.c_str());
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
            
            sprintf(delete_path, "%s%s", dir_.c_str(), name.c_str());
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
            
            sprintf(delete_path, "%s%s", dir_.c_str(), file_name.c_str());
            if (remove(delete_path) == 0) {
                current_cache_size = current_cache_size - file_size;
           
                if (max_disk_size_ >= current_cache_size) {
                    break;
                }
            }
        }
    }
    
}


void mx_file::write(const std::string &buf,const std::string &fname){
    
    if (fd_ == nullptr || filename_.compare(fname) != 0 || path_exists((dir_ + filename_).data()) == false) {
        filename_ = fname;
        open();
    }
    
    size_t msg_size = buf.size();
    auto data = buf.data();

    if( std::fwrite(data, 1, msg_size, fd_) != msg_size){
#ifdef __ANDROID__
        __android_log_print(ANDROID_LOG_ERROR, "file_helper::fwrite", "%s", "文件写入异常");
#elif __APPLE__
        printf("文件写入异常");
#endif

    }
}
void mx_file::set_header(std::string header){
    header_buffer_ = std::move(header) + "\n";
    
}
void mx_file::set_dir(const std::string dir){
    dir_ = dir;
    create_dir_(dir);
}
bool mx_file::create_dir_(const std::string &path){
    
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
        if (!subdir.empty() && !path_exists(subdir.data()) && makedir(subdir.data())!= 0) {
            
            return  false;
            
        }
        search_offset = token_pos + 1;
        
    } while (search_offset < dir_name.size());
    
    
    return true;
}


}
}
