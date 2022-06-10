//
//  mxlog.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "mxlogger.hpp"

#include <mutex>
#include <unordered_map>

#ifdef  __APPLE__
#include <sys/sysctl.h>
#endif
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "mmap_sink.hpp"
#include "mxlogger_helper.hpp"
#include "log_msg.hpp"
namespace mxlogger{

std::unordered_map<std::string, mxlogger *> *global_instanceDic_ =  new std::unordered_map<std::string, mxlogger *>;


static level::level_enum level_(int lvl){
  
    switch (lvl) {
        case 0:
            return level::level_enum::debug;
        case 1:
            return level::level_enum::info;
        case 2:
            return level::level_enum::warn;
        case 3:
            return level::level_enum::error;
        case 4:
            return level::level_enum::fatal;
            
        default:
            return level::level_enum::debug;
    }
    
}
static policy::storage_policy policy_(const char* storage_policy){
    
    if (storage_policy == nullptr) {
        return policy::storage_policy::yyyy_MM_dd;
    }
    if (strcmp(storage_policy, "yyyy_MM") == 0) {
        return policy::storage_policy::yyyy_MM;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd") == 0) {
        return policy::storage_policy::yyyy_MM_dd;
    }
    if (strcmp(storage_policy, "yyyy_ww") == 0) {
        return policy::storage_policy::yyyy_ww;
    }
    if (strcmp(storage_policy, "yyyy_MM_dd_HH") == 0) {
        return policy::storage_policy::yyyy_MM_dd_HH;;
    }
    return policy::storage_policy::yyyy_MM_dd;
}


/// 暂时先返回true
static bool is_debuging_() {
    return true;
    
//#ifdef __ANDROID__
//
//   return true;
//
//#elif __APPLE__
//    struct kinfo_proc procInfo;
//    size_t structSize = sizeof(procInfo);
//    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
//
//    if(sysctl(mib, sizeof(mib)/sizeof(*mib), &procInfo, &structSize, NULL, 0) != 0)
//    {
//        strerror(errno);
//        return false;
//    }
//
//    return (procInfo.kp_proc.p_flag & P_TRACED) != 0;
//
//#endif
//    return false;
}


 std::string mxlogger::md5(const char* ns,const char* directory){
     
     std::string diskcache_path = get_diskcache_path_(ns,directory);
     std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);

     return map_key;
}



std::string mxlogger::get_diskcache_path_(const char* ns,const char* directory){
    if (directory == nullptr) {
        return std::string{nullptr};
    }
    if (ns == nullptr) {
        ns = "default";
    }
    std::string  directory_s = std::string{directory};
    
    std::string ns_s = std::string{ns};
    
    std::string diskcache_path = directory_s + "/" + ns_s + "/";
    return diskcache_path;
}

mxlogger *mxlogger::initialize_namespace(const char* ns,const char* directory,const char* storage_policy,const char* file_name,const char* cryptKey, const char* iv){
    
    std::string diskcache_path = get_diskcache_path_(ns,directory);
    if (diskcache_path.data() == nullptr) {
        return nullptr;
    }
    
    std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);
    
    auto itr = global_instanceDic_ -> find(map_key);
    if (itr != global_instanceDic_ -> end()) {
        mxlogger * logger = itr -> second;
        return logger;
    }
    
    auto logger = new mxlogger(diskcache_path.c_str(),storage_policy,file_name,cryptKey,iv);
    logger -> map_key = map_key;
    (*global_instanceDic_)[map_key] = logger;
    return logger;
}

void mxlogger::delete_namespace(const char* ns,const char* directory){
    std::string diskcache_path = get_diskcache_path_(ns,directory);
    if (diskcache_path.data() == nullptr) {
        return;
    }
    std::string map_key =  mxlogger_helper::mx_md5(diskcache_path);
    for (auto &pair : *global_instanceDic_) {
         std::string key = pair.first;
        if (key == map_key) {
            delete pair.second;
            pair.second = nullptr;
        }
    }
}
void mxlogger::destroy(){
    
    for (auto &pair : *global_instanceDic_) {
        mxlogger *logger = pair.second;
        delete logger;
        pair.second = nullptr;
    }
  
    
}

mxlogger::mxlogger(const char *diskcache_path,const char* storage_policy,const char* file_name,const char* cryptKey, const char* iv) : diskcache_path_(diskcache_path),storage_policy_(storage_policy),file_name_(file_name){
    

//    std::pair<uint8_t*, uint8_t*> aes = mxlogger_helper::generate_crypt_key(cryptKey, iv);
//    if (aes.first != nullptr) {
//        AES_init_ctx_iv(&aes_ctx, aes.first, aes.second);
//    }
  
    
    mmap_sink_ = std::make_shared<sinks::mmap_sink>(diskcache_path,policy_(storage_policy));
    mmap_sink_ -> set_custom_filename(file_name);
    
    is_debug_tracking_ = is_debuging_();
    
    enable_ = true;
  
    
}

    

mxlogger::~mxlogger(){
    
}

const char* mxlogger::diskcache_path() const{
    return diskcache_path_.c_str();
}
const bool mxlogger::is_debug_tracking(){
    return is_debug_tracking_;
}
void mxlogger::set_enable(bool enable){
    
    enable_ = enable;
}


// 设置日志文件最大字节数(byte)
void mxlogger::set_file_max_size(const  long max_size){
    mmap_sink_ -> set_max_disk_size(max_size);
}

// 设置日志文件最大存储时长(s)
void mxlogger::set_file_max_age(const  long max_age){
    mmap_sink_ -> set_max_disk_age(max_age);
}

// 清理过期文件
void mxlogger::remove_expire_data(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> remove_expire_data();
}

//删除所有日志文件
void mxlogger::remove_all(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> remove_all();
}

// 缓存日志文件大小(byte)
long  mxlogger::dir_size(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    return mmap_sink_->dir_size();
}


void mxlogger::set_file_level(int level){
    mmap_sink_ -> set_level(level_(level));
}

void mxlogger::flush(){
    std::lock_guard<std::mutex> lock(logger_mutex);
    mmap_sink_ -> flush();
}

void mxlogger::log(int type, int level,const char* name, const char* msg,const char* tag,bool is_main_thread){
    
    std::lock_guard<std::mutex> lock(logger_mutex);
    if (enable_ == false) {
        return;
    }
    if (name == nullptr || strcmp(name, "") == 0) {
        name = "mxlogger";
    }
   


    
//    // 1、 flatbuffers 序列化为二进制数据
//    flatbuffers::FlatBufferBuilder builder;
//
//    auto root = Createlog_serializeDirect(builder,name,tag,msg,level,(uint32_t)details::logger_os::thread_id(),is_main_thread,mxlogger_helper::time_stamp_milliseconds());
//
//
//    builder.Finish(root);
//
//    uint8_t* point = builder.GetBufferPointer();
//    uint32_t size = builder.GetSize();
    
    
    //2、AES CFB 128位加密
   
    
    // mmap_sink_ -> log(builder_.GetBufferPointer(), builder_.GetSize(), level_(level));

   
}

}
