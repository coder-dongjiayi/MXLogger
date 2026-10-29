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
#include <limits>
namespace mxlogger{
namespace sinks{

base_file_sink::base_file_sink(const std::string &dir_path, const std::string &filename, policy::storage_policy policy):dir_path_(dir_path), policy_(policy),
#if MXLOGGER_MULTIPROCESS
    process_lock_(dir_path),
#endif
    filename_(filename){
    
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
    files::file_info info;
    return file_.valid() && file_.info(info) ? static_cast<size_t>(info.size) : mxlogger::file_size(log_disk_path_.data());
}
void base_file_sink::close(){
    if (!file_.close()) error_record = MXLoggerError("close error:%s\n", file_.error_message().c_str());
}
bool base_file_sink::ftruncate(size_t capacity_size){
    if (!file_.resize(capacity_size)) {
        error_record = MXLoggerError("truncate_ error:%s\n", file_.error_message().c_str());

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
    if (file_.valid()) return true;
    log_disk_path_ = dir_path_ + filename_;
    if (!file_.open(log_disk_path_, false, true)) {
        error_record = MXLoggerError("open_file error:%s\n", file_.error_message().c_str());
        return  false;
    }
#if MXLOGGER_MULTIPROCESS
#ifdef _WIN32
    files::file_info info;
    if (!file_.info(info)) {
        error_record = MXLoggerError("file info error:%s\n", file_.error_message().c_str());
        close();
        return false;
    }
    if (!active_lease_.hold(dir_path_, info)) {
        error_record = MXLoggerError("active file lease error:%s\n", active_lease_.error_message().c_str());
#else
    if (!file_.lock(false)) {
        error_record = MXLoggerError("data file lock error:%s\n", file_.error_message().c_str());
#endif
        close();
        return false;
    }
#endif
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
#if MXLOGGER_MULTIPROCESS
    ipc::directory_lock directory_lock(dir_path_, false);
    ipc::scoped_lock lock(directory_lock, false);
    if (!lock) return 0;
#endif
   
    int64_t current_cache_size = 0;
    
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_path_.c_str());
    
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        const int64_t size = std::stoll(map["size"]);
        // Preserve the public long return type without overflowing on Windows.
        if (size > std::numeric_limits<long>::max() - current_cache_size) {
            return std::numeric_limits<long>::max();
        }
        current_cache_size += size;
        
    }
    
    return static_cast<long>(current_cache_size);
    
  
}

bool base_file_sink::is_active_file_(const std::string &name) {
    if (name == filename_) return true;
    const std::string path = dir_path_ + name;
    // Only cleanup checks identities, including a mapped file renamed by an
    // external tool or reached through another spelling/link. No write-time stat.
    if (file_.valid()) {
        files::file_info opened, candidate;
        std::error_code error;
        if (!file_.info(opened) || !files::path_info(path, candidate, error)) return true;
        if (opened.same_file(candidate)) return true;
    }
#if MXLOGGER_MULTIPROCESS
    return !ipc::file_is_inactive(path);
#else
    return false;
#endif
}

// 删除过期文件
void base_file_sink::remove_expire_data(){

     if (max_disk_age_ <= 0 && max_disk_size_ <= 0) {
         return;
     }
#if MXLOGGER_MULTIPROCESS
     ipc::scoped_lock lock(process_lock_);
     if (!lock) {
         error_record = MXLoggerError("cleanup lock error:%s\n", lock.error_message().c_str());
         return;
     }
#endif

     int64_t current_cache_size = 0;
   
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
         int64_t size = std::stoll(map["size"]);
         int64_t last_time = std::stoll(map["last_timestamp"]);

         bool can_expire = max_disk_age_ > 0 && last_time < expiration_tp && !is_active_file_(file_name);
         if (can_expire) {
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
             if (mxlogger::remove_file(delete_path.c_str()) != 0) {

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
             int64_t file_size = std::stoll(map["size"]);

             std::string delete_path = dir_path_ + file_name;

             // 如果需要清理的文件是当前正在写入的文件 则不进行清理
             if(is_active_file_(file_name)){
                 MXLoggerInfo("%s is currently being mapped and will not be deleted",file_name.c_str());
                 continue;
             }
             if (mxlogger::remove_file(delete_path.c_str()) == 0) {
                 current_cache_size = current_cache_size - file_size;
                 MXLoggerInfo("over limit size file : %s(%lld byte)",file_name.c_str(),static_cast<long long>(file_size));
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


int base_file_sink::remove_all_(){
#if MXLOGGER_MULTIPROCESS
    ipc::scoped_lock lock(process_lock_);
    if (!lock) {
        error_record = MXLoggerError("cleanup lock error:%s\n", lock.error_message().c_str());
        return 0;
    }
#endif
    std::vector<std::map<std::string, std::string>> destination;
    
    mxlogger::get_files(&destination, dir_path_.c_str());
    
    int count_ = 0;
    for (int i = 0; i < destination.size(); i++) {
        std::map<std::string, std::string> map = destination[i];
        std::string file_name  = map["name"];
        /// 不删除当前正在写入日志的文件
        if(is_active_file_(file_name)){
            continue;
        }
        std::string subdir = dir_path_ + file_name;
        if (mxlogger::remove_file(subdir.c_str()) == 0) {
            count_++;
        } else {
            error_record = MXLoggerError("delete %s failed: %s", file_name.c_str(), strerror(errno));
        }
    }
    return count_;

}
// Both cleanup entry points preserve files owned by active loggers.
void base_file_sink::remove_all(){
   int files = remove_all_();
    MXLoggerInfo("remove_all  files:(%d)",files);
}
void base_file_sink::remove_before_all(){
     int files = remove_all_();
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

