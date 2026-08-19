//
//  mmap_sink.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/29.
//

#include "mmap_sink.hpp"
#ifdef _WIN32
#include <windows.h>
#include <io.h>
#else
#include <sys/mman.h>
#include <unistd.h>
#endif
#include <cerrno>
#include "../log_serialize.h"


static const size_t offset_length = sizeof(uint32_t);

/// 系统内存页大小，映射文件按页对齐扩容
static size_t os_page_size(){
#ifdef _WIN32
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    return static_cast<size_t>(info.dwPageSize);
#else
    return static_cast<size_t>(getpagesize());
#endif
}


namespace mxlogger{
namespace sinks{
mmap_sink::mmap_sink(const std::string &dir_path, const std::string &filename,policy::storage_policy policy):base_file_sink(dir_path,filename,policy),page_size_(os_page_size()){

    
    open();
    file_size_ = get_file_size();
    if (file_size_ == 0) {
        truncate_(0);
        
    }else{
        mmap_();
    }

    actual_size_ = get_actual_size_();

    /// 文件头记录的actual_size超过文件容量说明文件已损坏(如被外部截断或上次写入中断)，
    /// 直接信任会导致后续写入越界，此处重置为0从头写入
    /// An actual_size beyond the file capacity means the file is corrupted (externally
    /// truncated or a previous write was interrupted); trusting it would make later
    /// writes run out of bounds, so reset to 0 and start over
    if (actual_size_ + offset_length > file_size_) {
        actual_size_ = 0;
        if (mmap_ptr_ != nullptr) {
            write_actual_size_(0);
        }
    }
}
mmap_sink::~mmap_sink(){
    munmap_();
    MXLoggerInfo("mmap_sink delloc");
}
int mmap_sink::log(const details::log_msg& msg){
    if (should_log(msg.level) == false) {
        return 0;
    }
    
    return  log_(msg);
}

void mmap_sink::add_file_heder(const char* msg){
    
    if(actual_size_ !=0 || msg == nullptr) return;
    details::log_msg log_msg(level::level_enum::debug,"com.djy.mxlogger.fileHeader",nullptr,msg,true);
    log_(log_msg);
}


int mmap_sink::log_(const details::log_msg& msg){
    flatbuffers::FlatBufferBuilder builder;
    
    auto root =  Createlog_serializeDirect(builder,msg.name,msg.tag,msg.msg,msg.level,(uint32_t)msg.thread_id,msg.is_main_thread,msg.time_stamp);
   
    builder.Finish(root);
     auto buffer =  builder.Release();
    
    uint8_t* point = buffer.data();
    uint32_t size = (uint32_t)buffer.size();
    
    
    if (should_encrypt()) {
        cfb128_encrypt(point, point, size);
    }
    
    return  write_data_(point, size);
 
}

int mmap_sink::write_data_(const void* buffer, size_t buffer_size){


    ///1.、需要写入字节总大小 = 当前文件真实长度 + 需要写入buffer的长度 + offset_length

    size_t total = actual_size_ + buffer_size + offset_length;

    /// 2、如果需要的空间大于文件长度进行扩容。
    /// 文件布局为[4字节actual_size头][数据区]，实际需要 total + offset_length 字节；
    /// 原来按 total >= file_size_ 判断少算了4字节文件头，total落在页尾3字节窗口内时
    /// 不触发扩容，写入会越出mmap映射区导致段错误
    /// The file layout is [4-byte actual_size header][data], so total + offset_length
    /// bytes are required. The old check (total >= file_size_) ignored the 4-byte header:
    /// when total landed within 3 bytes of the page end, no expansion was triggered and
    /// the write ran past the mapped region, crashing with SIGSEGV
    size_t required = total + offset_length;
    if (required > file_size_) {
        /// 扩容逻辑失败 就不往下进行了
       int r =  truncate_(required);
        if(r != 0){
            return r;
        }
    }

    /// 之前映射失败(如磁盘满、权限异常)会导致mmap_ptr_为空，重新尝试映射，仍失败则放弃本次写入
    if (mmap_ptr_ == nullptr && mmap_() == false) {
        return -3;
    }

    uint8_t* write_ptr = mmap_ptr_  + offset_length + actual_size_;
    
    
    ///3.、先写入buffer 长度
    memcpy(write_ptr, &buffer_size, offset_length);
    
  
    ///4、 再写buffer数据
    memcpy(write_ptr + offset_length, buffer, buffer_size);
    
    
    ///5、更新文件真实大小
    write_actual_size_(total);

    return 0;
}

void mmap_sink::write_actual_size_(size_t size){
    
    memcpy(mmap_ptr_, &size, offset_length);
    
    actual_size_ = size;
}

size_t mmap_sink::get_actual_size_(){
    /// 构造时映射失败mmap_ptr_可能为空
    if (mmap_ptr_ == nullptr) {
        return 0;
    }
    uint32_t actual_size;

    memcpy(&actual_size, mmap_ptr_, offset_length);

    return actual_size;
}
//扩容
/// 0 成功  -1 扩容失败 -2 解除映射失败 -3 映射失败
int mmap_sink::truncate_(size_t size){

    size_t capacity_size =  (( size / page_size_) + 1) * page_size_;

    /// Windows下文件被映射时无法调整大小，统一先解除映射再扩容(POSIX下此顺序同样安全)
    if(munmap_() == false){
        return -2;
    }
    if(ftruncate(capacity_size) == false){
        return -1;
    }

    file_size_ = capacity_size;

    if(mmap_() == false){
        return -3;
    }
    return 0;

}
// 解除映射
bool mmap_sink::munmap_(){
    if(mmap_ptr_ != nullptr){
#ifdef _WIN32
        if (UnmapViewOfFile(mmap_ptr_) == 0) {

            error_record = MXLoggerError("munmap_ error:%lu",GetLastError());


            return false;
        }
#else
        if (munmap(mmap_ptr_, file_size_) != 0) {

            error_record = MXLoggerError("munmap_ error:%s",strerror(errno));


            return false;
        }
#endif
        error_record = "";
        mmap_ptr_ = nullptr;
    }
#ifdef _WIN32
    if (file_mapping_ != nullptr) {
        CloseHandle((HANDLE)file_mapping_);
        file_mapping_ = nullptr;
    }
#endif
    return true;
}

// 建立文件与内存的映射
bool mmap_sink::mmap_(){

#ifdef _WIN32
    HANDLE file_handle = (HANDLE)_get_osfhandle(file_ident);
    if (file_handle == INVALID_HANDLE_VALUE) {
        error_record = MXLoggerError("[mxlogger_error]start_mmap invalid fd\n");
        return false;
    }

    file_mapping_ = CreateFileMappingW(file_handle, NULL, PAGE_READWRITE,
                                       (DWORD)(((uint64_t)file_size_) >> 32),
                                       (DWORD)(file_size_ & 0xFFFFFFFF), NULL);
    if (file_mapping_ == nullptr) {
        error_record = MXLoggerError("[mxlogger_error]CreateFileMapping error:%lu\n",GetLastError());
        close();
        return false;
    }

    mmap_ptr_ = (uint8_t*)MapViewOfFile((HANDLE)file_mapping_, FILE_MAP_ALL_ACCESS, 0, 0, file_size_);
    if (mmap_ptr_ == nullptr) {
        error_record = MXLoggerError("[mxlogger_error]MapViewOfFile error:%lu\n",GetLastError());
        CloseHandle((HANDLE)file_mapping_);
        file_mapping_ = nullptr;
        close();
        return false;
    }
#else
    mmap_ptr_ =  (uint8_t*)::mmap(NULL, file_size_, PROT_READ|PROT_WRITE, MAP_SHARED, file_ident, 0);

    if (mmap_ptr_ == MAP_FAILED) {
        mmap_ptr_ = nullptr;

        error_record = MXLoggerError("[mxlogger_error]start_mmap error:%s\n",strerror(errno));

        close();

        return  false;
    }
#endif
    error_record = "";

    return  true;
}

void mmap_sink::flush() {
    async_();
}
bool mmap_sink::msync_(bool is_sync){
    if (mmap_ptr_ == nullptr) {
        return false;
    }
#ifdef _WIN32
    if (FlushViewOfFile(mmap_ptr_, 0) == 0) {

        error_record =  MXLoggerError("[mxlogger_error]msync_ error:%lu\n",GetLastError());

        return false;
    }
    if (is_sync) {
        /// FlushViewOfFile是异步写回，同步语义需要再刷文件缓冲
        FlushFileBuffers((HANDLE)_get_osfhandle(file_ident));
    }
#else
    if (msync(mmap_ptr_, get_file_size(), is_sync ? MS_SYNC : MS_ASYNC) != 0) {

        error_record =  MXLoggerError("[mxlogger_error]msync_ error:%s\n",strerror(errno));

        return false;
    }
#endif
    error_record = "";
    return true;

}

bool mmap_sink::sync_(){

    return msync_(true);
}

bool mmap_sink::async_(){
    return msync_(false);
}


};


};
