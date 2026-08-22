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
    if (file_ident >= 0) {
#ifdef _WIN32
        ::_close(file_ident);
#else
        ::close(file_ident);
#endif
    }
    file_ident = -1;
}
bool base_file_sink::ftruncate(size_t capacity_size){

#ifdef _WIN32
    if (::_chsize_s(file_ident, (long long)capacity_size) != 0) {
#else
    if (::ftruncate(file_ident, static_cast<off_t>(capacity_size)) != 0) {
#endif
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
    if (path_exists(file_path.data()) == true && file_ident >= 0)  return true;


    if (file_ident >= 0) {
        close();
    }
        
    log_disk_path_ = file_path;

    /// 打开文件，如果文件不存在则创建文件
#ifdef _WIN32
    file_ident =  ::_wopen(mxlogger::utf8_to_wide(log_disk_path_.c_str()).c_str(),
                           _O_RDWR | _O_CREAT | _O_BINARY | _O_NOINHERIT, _S_IREAD | _S_IWRITE);
#else
    file_ident =  ::open(log_disk_path_.c_str(), O_RDWR|O_CLOEXEC|O_CREAT,S_IRWXU);
#endif
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

long long base_file_sink::max_disk_age() const{
    return max_disk_age_;
}

long long base_file_sink::max_disk_size() const{
    return max_disk_size_;
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

     if (max_disk_age_ <= 0 && max_disk_size_ <= 0) {
         return;
     }

     long   current_cache_size=0;
   
     std::vector<std::string> delete_urls;
     std::vector<std::map<std::string, std::string>> final_dir;
     
     std::tm tm_time = mxlogger_helper::now();
     
     long long int timestamp =  mktime(&tm_time);
     long long int expiration_tp = timestamp - max_disk_age_;
     
     std::vector<std::map<std::string, std::string>> destination;

     // step1 遍历文件找出过期文件，统计文件size
     // 注意：size统计必须在max_disk_age_判断之外，否则只设置max_disk_size时step2永远不会触发
     mxlogger::get_files(&destination, dir_path_.c_str());
     for (int i = 0; i < destination.size(); i++) {
         std::map<std::string, std::string> map = destination[i];
         std::string file_name  = map["name"];
         long size = std::stol(map["size"]);
         time_t last_time = (time_t)std::stol(map["last_timestamp"]);

         if (max_disk_age_ > 0 && last_time < expiration_tp && file_name.compare(filename_) != 0) {
             /// 过期文件
             delete_urls.push_back(file_name);

             continue;
         }else{
             final_dir.push_back(map);
         }
         current_cache_size = current_cache_size + size;

     }
     if (delete_urls.size() > 0) {
         MXLoggerInfo("start delete expire data(%zu files)...",delete_urls.size());
         //删除过期文件
         for (int i = 0; i< delete_urls.size(); i++) {

             std::string name = delete_urls[i];

             std::string delete_path = dir_path_ + name;
             MXLoggerInfo("expire file : %s",name.c_str());
             if (remove(delete_path.c_str()) != 0) {

                 error_record =  MXLoggerError("delete %s failed!!!",name.c_str());
             }

         }
     }


   // step2 清理大于目标size的文件
     if (max_disk_size_ > 0 && current_cache_size > max_disk_size_) {
         int removeCount = 0;

         MXLoggerInfo("start over limit data...");
         // final_dir按创建时间降序排列，从末尾(最旧的文件)开始删
         for (int i = (int)final_dir.size() - 1; i >= 0; i--) {
             std::map<std::string, std::string> map = final_dir[i];
             std::string file_name  = map["name"];
             long file_size = std::stol(map["size"]);

             std::string delete_path = dir_path_ + file_name;

             // 如果需要清理的文件是当前正在写入的文件 则不进行清理
             if( file_name.compare(filename_) == 0){
                 MXLoggerInfo("%s is currently being mapped and will not be deleted",file_name.c_str());
                 continue;
             }
             if (remove(delete_path.c_str()) == 0) {
                 current_cache_size = current_cache_size - file_size;
                 MXLoggerInfo("over limit size file : %s(%ld byte)",file_name.c_str(),file_size);
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
        /// 不删除当前正在写入日志的文件
        if(skip_current == true && file_name == filename_){
            continue;
        }
        count_ ++;
        std::string subdir = dir_path_ + file_name;
        remove(subdir.c_str());
    }
    return count_;

}
// 删除所有日志文件
void base_file_sink::remove_all(){
   int files =  remove_all_(false);
    MXLoggerInfo("remove_all  files:(%d)",files);
}
void base_file_sink::remove_before_all(){
     int files = remove_all_(true);
    MXLoggerInfo("remove_before_all  files:(%d)",files);
}

/// 根据存储策略生成带日期前缀的文件名，仅在构造时调用一次。
/// 设计说明：文件名在logger初始化时一次性确定，运行期间不随日期变化滚动，
/// 切换新文件发生在App下一次初始化logger的时候
/// Generates the date-prefixed file name from the storage policy; called once at
/// construction. By design the name is fixed at initialization and never rolls over
/// at runtime — switching to a new file happens the next time the app initializes
/// the logger
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
            /// 与其他策略保持一致使用本地时间，原来用gmtime会导致跨时区周界不一致
            int wd = tm_time.tm_wday;
            int yd = tm_time.tm_yday;
            /// 周数定义：周日为一周起点，1月1日所在周为第1周。
            /// w0 = 当年1月1日是星期几(周日=0)，对负数取模做非负规整——
            /// 原写法在年初 yd < wd 时 (yd-wd)%7 为负数(C++截断取模)，导致周号整体+1，
            /// 例如2024-01-01~01-06会被错记为02w并与真正的第2周写进同一个文件
            /// Week definition: weeks start on Sunday and the week containing Jan 1st is
            /// week 1. w0 is the weekday of Jan 1st (Sunday = 0), normalized to a
            /// non-negative modulus — the old formula went negative when yd < wd in the
            /// first days of a year (C++ truncated modulo), shifting the week number up
            /// by one, e.g. 2024-01-01~01-06 was mislabeled 02w and shared a file with
            /// the real week 2
            int w0 = ((wd - yd) % 7 + 7) % 7;
            int week_n = (yd + w0) / 7 + 1;

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
            /// 未知策略保留原始文件名，不加日期前缀
            break;
    }
    filename_ = filename_ + ".mx";
    
    
}
}
}

