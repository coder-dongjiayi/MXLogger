//
//  base_file_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/6/8.
//

#include "base_file_sink.hpp"
#include <map>
#include "../mxlogger_helper.hpp"
#include "../mxlogger_file_util.hpp"
#include <cerrno>
namespace mxlogger{
namespace sinks{

base_file_sink::base_file_sink(const std::string &dir_path, const std::string &filename, policy::storage_policy policy):dir_path_(dir_path), filename_(filename), policy_(policy){
    
    if (mxlogger::create_dir(dir_path) == false) {
       error_record =  MXLoggerError("base_file_sink error:%s\n",strerror(errno));
    }

    handle_date_(policy);
    
}
base_file_sink::~base_file_sink(){
    close();
    MXLoggerInfo("base_file_sink delloc");
}

size_t base_file_sink::get_file_size(){
    return mxlogger::file_size(log_disk_path_.data());
}
void base_file_sink::close(){
    ::close(file_ident);
    file_ident = -1;
}
bool base_file_sink::ftruncate(size_t capacity_size){
    
    if (::ftruncate(file_ident, static_cast<off_t>(capacity_size)) != 0) {
        error_record =  MXLoggerError("truncate_ error:%s\n",strerror(errno));
         
        return  false;
    }else{
        error_record = "";
    }
    
    return true;
}
bool base_file_sink::is_exit_path(){
    
    return path_exists(log_disk_path_.data());
}

bool base_file_sink::open(){
    
    std::string file_path = dir_path_ + filename_;
    if (path_exists(file_path.data()) == true && file_ident > 0)  return true;
    
    
    if (file_ident > 0) {
        close();
    }
        
    log_disk_path_ = file_path;
    
    /// 打开文件，如果文件不存在则创建文件
    file_ident =  ::open(log_disk_path_.c_str(), O_RDWR|O_CLOEXEC|O_CREAT,S_IRWXU);
    if (file_ident < 0) {
        error_record =  MXLoggerError("ope_file_ error:%s\n",strerror(errno));
        return  false;
    }
    error_record = "";
 
    return true;
}


// 文件最大存储时间 默认为0 不限制
void base_file_sink::set_max_disk_age(long long max_age){
    max_disk_age_ = max_age;
    MXLoggerInfo("max_age:%llds",max_age);
}

// 文件最大存储大小 默认为0 不限制
void base_file_sink::set_max_disk_size(long long max_size){
    max_disk_size_ = max_size;
    MXLoggerInfo("max_size:%lld byte",max_size);
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
             time_t last_time = (time_t)std::stol(map["last_timestamp"]);
             
             if (last_time < expiration_tp && file_name.compare(filename_) != 0) {
                 /// 过期文件
                 delete_urls.push_back(file_name);
                
                 continue;
             }else{
                 final_dir.push_back(map);
             }
             current_cache_size = current_cache_size + size;
            
         }
         MXLoggerInfo("start delete expire data(%ld files)...",delete_urls.size());
         //删除过期文件
         for (int i = 0; i< delete_urls.size(); i++) {
             char delete_path[256];
             
             std::string name = delete_urls[i];
             
             sprintf(delete_path, "%s%s", dir_path_.c_str(), name.c_str());
             MXLoggerInfo("expire file : %s",name.c_str());
             if (remove(delete_path) != 0) {
                 
                 error_record =  MXLoggerError("delete delete_path field!!!",name.c_str());
             }
             
         }
     }
    
    
   // step2 清理大于目标size的文件
     if (max_disk_size_ > 0 && current_cache_size > max_disk_size_) {
         int removeCount = 0;
         
         MXLoggerInfo("start over limit data...");
         for (int i = 0; i < final_dir.size(); i++) {
             std::map<std::string, std::string> map = final_dir[i];
             std::string file_name  = map["name"];
             long file_size = std::stol(map["size"]);
             char delete_path[256];
             
             sprintf(delete_path, "%s%s", dir_path_.c_str(), file_name.c_str());
            
             // 如果需要清理的文件是当前正在写入的文件 则不进行清理
             if( file_name.compare(filename_) == 0){
                 MXLoggerInfo("%s is currently being mapped and will not be deleted",file_name.c_str());
                 continue;
             }
             if (remove(delete_path) == 0) {
                 current_cache_size = current_cache_size - file_size;
                 MXLoggerInfo("over limit size file : %s(%lld byte)",file_name.c_str(),file_size);
                 removeCount = removeCount + 1;
                 if (max_disk_size_ >= current_cache_size) {
                     MXLoggerInfo("over limit data(%d files)...",removeCount);
                     break;
                 }
             }
         }
         MXLoggerInfo("end over limit data...");
     }
   
    
}


int base_file_sink::remove_all_(bool skip_current){
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_path_.c_str());
    
    int count_ = 0;
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        std::string file_name  = map["name"];
        char subdir[256];
        /// 不删除当前正在写入日志的文件
        if(skip_current == true && file_name == filename_){
            continue;
        }
        count_ ++;
        sprintf(subdir, "%s%s", dir_path_.c_str(), file_name.c_str());
        remove(subdir);
    }
    return count_;
   
}
// 删除所有日志文件
void base_file_sink::remove_all(){
   int files =  remove_all_(false);
    MXLoggerInfo("remove_all  files:(%ld)",files);
}
void base_file_sink::remove_before_all(){
     int files = remove_all_(true);
    MXLoggerInfo("remove_before_all  files:(%ld)",files);
}

void base_file_sink::handle_date_(policy::storage_policy policy){


    std::tm tm_time = mxlogger_helper::now();

    int tm_mon = tm_time.tm_mon + 1;
    int tm_year = tm_time.tm_year + 1900;
    int tm_mday = tm_time.tm_mday;
    int tm_hour = tm_time.tm_hour;
    
    switch (policy) {
        case policy::storage_policy::yyyy_MM:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d", tm_year,tm_mon);
            filename_ = result + "_" + filename_;
        }
            break;
        case policy::storage_policy::yyyy_ww:
        {
            int wd = 0 , yd = 0;
            time_t t;
            struct tm *ptr;
            time(&t);
            ptr = gmtime(&t);
            wd = ptr->tm_wday;
            yd = ptr->tm_yday;
            int base = 7 - (yd + 1 - (wd + 1)) % 7;
            if (base == 7){
                base = 0;
            }
           int  week_n = (base + yd) / 7 + 1;

            auto result = mxlogger_helper::string_format("%04d-%02d-%02dw",  tm_year, tm_mon,week_n);

            filename_ = result + "_" + filename_;
        }
            break;
        case policy::storage_policy::yyyy_MM_dd:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d", tm_year, tm_mon, tm_mday);
            filename_ = result + "_" + filename_;
        }

            break;
        case policy::storage_policy::yyyy_MM_dd_HH:
        {
            auto result = mxlogger_helper::string_format("%04d-%02d-%02d-%02d", tm_year, tm_mon, tm_mday, tm_hour);

            filename_ = result + "_" + filename_;
        }
            break;

        default:
            filename_ = "null";
            break;
    }
    filename_ = filename_ + ".mx";
    
    
}
}
}

