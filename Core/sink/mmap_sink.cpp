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
#include <limits>
#if MXLOGGER_MULTIPROCESS
#include <sys/stat.h>
#endif
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

    /// 构造时失败(如目录暂不可写)不致命：write_data_每次写入前会走同一条恢复路径重试
    /// A failure here (e.g. the directory is temporarily unwritable) is not fatal:
    /// write_data_ retries through this same recovery path before every write
    recover_mmap_();
#ifdef _WIN32
    // Start caching only after the initial recovery finishes. A
    // throwing constructor must never leave a callback into a partial sink.
    process_lock_.configure_mapping_cache(this, [](void *context) {
        return static_cast<mmap_sink *>(context)->release_windows_mapping_();
    });
#endif
}

bool mmap_sink::recover_mmap_(){
#if MXLOGGER_MULTIPROCESS
    ipc::scoped_lock lock(process_lock_);
    if (!lock) {
        error_record = MXLoggerError("initialization lock error:%s\n", lock.error_message().c_str());
        return false;
    }
    transaction_cleanup cleanup{*this};
    return refresh_mmap_();
#else

    /// fd丢失(初次open失败或映射失败)时重开文件，open对不存在的文件会重新创建
    /// Reopen the file when the fd is lost (initial open or a mapping failed);
    /// open() recreates the file when it no longer exists
    if (!file_.valid() && open() == false) {
        return false;
    }

    file_size_ = get_file_size();
    if (file_size_ == 0) {
        /// 空文件先按页对齐扩容，truncate_内部会完成映射
        /// Page-align the empty file first; truncate_ establishes the mapping itself
        if (truncate_(0) != 0) {
            return false;
        }
    }else if (mmap_ptr_ == nullptr && mmap_() == false) {
        return false;
    }

    if (mmap_ptr_ == nullptr) {
        return false;
    }

    actual_size_ = get_actual_size_();

    /// 文件头记录的actual_size超过文件容量说明文件已损坏(如被外部截断或上次写入中断)，
    /// 直接信任会导致后续写入越界，此处重置为0从头写入
    /// An actual_size beyond the file capacity means the file is corrupted (externally
    /// truncated or a previous write was interrupted); trusting it would make later
    /// writes run out of bounds, so reset to 0 and start over
    if (actual_size_ + offset_length > file_size_) {
        actual_size_ = 0;
        write_actual_size_(0);
    }
    return true;
#endif
}
#if MXLOGGER_MULTIPROCESS
bool mmap_sink::refresh_mmap_() {
#ifdef _WIN32
    // No cooperating exclusive transaction can touch this directory until it
    // has evicted our retained view. Avoid reopening the path and querying its
    // identity/size on each record while that protection remains ours.
    if (mmap_ptr_ && process_lock_.cached_mapping()) {
        actual_size_ = get_actual_size_();
        if (actual_size_ > file_size_ - offset_length) {
            error_record = MXLoggerError("invalid committed data length:%zu\n", actual_size_);
            return false;
        }
        return true;
    }
#endif
    // Keep the existing handle/mapping even if an external tool unlinks or
    // replaces its path. Only query the open file's capacity: cooperating
    // processes may have grown it since our previous write.
    files::file_info opened;
    if (!file_.valid()) {
#ifdef _WIN32
        // Timestamp state belongs to this OS handle lifetime.
        write_time_.reset();
#endif
        if (!open()) return false;
    }
    if (!file_.info(opened) || opened.size > std::numeric_limits<size_t>::max()) {
        error_record = MXLoggerError("file size error:%s\n", file_.error_message().c_str());
        return false;
    }
    const size_t capacity = static_cast<size_t>(opened.size);
    if (mmap_ptr_ != nullptr && capacity != file_size_ && !munmap_()) return false;
    file_size_ = capacity;
    if (capacity == 0) {
        if (truncate_(0) != 0) return false;
    } else {
        if (capacity < offset_length) {
            error_record = MXLoggerError("invalid log file size:%zu\n", capacity);
            return false;
        }
        if (mmap_ptr_ == nullptr && !mmap_()) return false;
    }
    actual_size_ = get_actual_size_();
    if (actual_size_ > file_size_ - offset_length) {
        error_record = MXLoggerError("invalid committed data length:%zu\n", actual_size_);
        return false;
    }
    error_record.clear();
    return true;
}
#endif
mmap_sink::transaction_cleanup::~transaction_cleanup() {
#ifdef _WIN32
    if (sink.process_lock_.retain_mapping(sink.mmap_ptr_ != nullptr)) return;
    if (sink.munmap_()) sink.close();
#endif
}

#ifdef _WIN32
bool mmap_sink::flush_windows_write_time_() {
    return write_time_.flush([this](uint64_t ticks) { return file_.update_write_time(ticks); });
}
bool mmap_sink::release_windows_mapping_() {
    // This callback also runs on the eviction thread under the cache mutex.
    // Leave public error_record alone; the cache reports callback failures.
    if (!flush_windows_write_time_()) return false;
    const bool unmapped = mapping_.unmap();
    mmap_ptr_ = mapping_.data();
    if (!unmapped || !file_.close()) return false;
    write_time_.reset();
    return true;
}
#endif

mmap_sink::~mmap_sink(){
#ifdef _WIN32
    process_lock_.stop_mapping_cache();
#endif
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
#if MXLOGGER_MULTIPROCESS
    if (msg == nullptr) return;
    details::log_msg log_msg(level::level_enum::debug,"com.djy.mxlogger.fileHeader",nullptr,msg,true);
    // The empty check and append share ONE locked transaction, including when
    // several processes initialize the same empty file simultaneously.
    log_(log_msg, true);
#else
    if(actual_size_ !=0 || msg == nullptr) return;
    details::log_msg log_msg(level::level_enum::debug,"com.djy.mxlogger.fileHeader",nullptr,msg,true);
    log_(log_msg);
#endif
}


int mmap_sink::log_(const details::log_msg& msg, bool only_if_empty){
    flatbuffers::FlatBufferBuilder builder;
    
    auto root =  Createlog_serializeDirect(builder,msg.name,msg.tag,msg.msg,msg.level,(uint32_t)msg.thread_id,msg.is_main_thread,msg.time_stamp);
   
    builder.Finish(root);
     auto buffer =  builder.Release();
    
    uint8_t* point = buffer.data();
    uint32_t size = (uint32_t)buffer.size();
    
    
    if (should_encrypt()) {
        cfb128_encrypt(point, point, size);
    }
    
    return  write_data_(point, size, only_if_empty);
 
}

int mmap_sink::write_data_(const void* buffer, size_t buffer_size, bool only_if_empty){
#if MXLOGGER_MULTIPROCESS
    ipc::scoped_lock lock(process_lock_);
    if (!lock) {
        error_record = MXLoggerError("write lock error:%s\n", lock.error_message().c_str());
        return -4;
    }
    transaction_cleanup cleanup{*this};
    if (!refresh_mmap_()) return -3;
    if (only_if_empty && actual_size_ != 0) return 0;
#else
    (void)only_if_empty;

    /// 0、映射缺失(构造失败或上次映射失败)时先自愈：重开文件/重建映射并从
    /// 文件头恢复actual_size_，防止内存中的偏移与磁盘脱节；仍失败则放弃本次写入。
    /// 必须在计算total之前做，否则会用失效的actual_size_/file_size_推算扩容
    /// 0. Self-heal first when the mapping is missing (construction or a previous
    /// mapping failed): reopen the file / re-establish the mapping and restore
    /// actual_size_ from the file header so the in-memory offset cannot drift from
    /// the on-disk state; give up this write if recovery still fails. This must run
    /// before computing total — otherwise the expansion math uses stale
    /// actual_size_ / file_size_
    if (mmap_ptr_ == nullptr && recover_mmap_() == false) {
        return -3;
    }
#endif

    // The on-disk committed length is uint32_t on every platform, including
    // Windows x64. Reject an append before the serialized length can wrap.
    constexpr size_t max_length = static_cast<size_t>(std::min<uint64_t>(
        std::numeric_limits<uint32_t>::max(), std::numeric_limits<size_t>::max() - offset_length));
    if (buffer_size > max_length - offset_length || actual_size_ > max_length - offset_length - buffer_size) {
        error_record = MXLoggerError("log exceeds uint32 length limit\n");
        return -4;
    }

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

#ifdef _WIN32
    const uint64_t write_time = files::file_time_now();
    // First append in each wall-clock second publishes mtime before the record.
    // Same-second appends defer the exact tick until flush/mapping release.
    if (!write_time_.prepare(write_time, [this](uint64_t ticks) { return file_.update_write_time(ticks); })) {
        error_record = MXLoggerError("update write time error:%s\n", file_.error_message().c_str());
        return -1;
    }
#endif
    uint8_t* write_ptr = mmap_ptr_  + offset_length + actual_size_;
    
    
    ///3.、先写入buffer 长度
    memcpy(write_ptr, &buffer_size, offset_length);
    
  
    ///4、 再写buffer数据
    memcpy(write_ptr + offset_length, buffer, buffer_size);
    
    
    ///5、更新文件真实大小
    write_actual_size_(total);
#ifdef _WIN32
    write_time_.commit(write_time);
#endif

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
    if (page_size_ == 0 || size > std::numeric_limits<size_t>::max() - page_size_) {
        error_record = MXLoggerError("mapping capacity overflow\n");
        return -1;
    }
    size_t capacity_size =  (( size / page_size_) + 1) * page_size_;
#if defined(_WIN32) || MXLOGGER_MACOS_MULTIPROCESS
    // Desktop files start at 64 KiB, then grow geometrically with at most
    // 1 MiB added per ordinary growth. Mobile keeps its page-sized policy.
    // The committed-length header and record format remain unchanged.
    constexpr size_t granularity = 64 * 1024;
    const size_t headroom = std::min(std::max(file_size_, granularity), size_t(1024 * 1024));
    size_t target = size;
    if (file_size_ <= std::numeric_limits<size_t>::max() - headroom)
        target = std::max(target, file_size_ + headroom);
    if (target > std::numeric_limits<size_t>::max() - (granularity - 1)) {
        error_record = MXLoggerError("mapping capacity overflow\n");
        return -1;
    }
    capacity_size = ((target + granularity - 1) / granularity) * granularity;
#endif
    const bool was_empty = file_size_ == 0;

    /// Windows下文件被映射时无法调整大小，统一先解除映射再扩容(POSIX下此顺序同样安全)
    if(munmap_() == false){
        return -2;
    }
    if(ftruncate(capacity_size) == false){
        return -1;
    }
    // Initialize the length before mapping, including if mapping later fails
    // and must be retried. SetEndOfFile leaves extended contents unspecified.
    if (was_empty) {
        const uint32_t empty = 0;
        if (file_.write_at(&empty, sizeof(empty), 0) != sizeof(empty)) {
            error_record = MXLoggerError("initialize file header error:%s\n", file_.error_message().c_str());
            return -1;
        }
    }

    file_size_ = capacity_size;

    if(mmap_() == false){
        return -3;
    }
    return 0;

}
// 解除映射
bool mmap_sink::munmap_(){
#ifdef _WIN32
    if (!flush_windows_write_time_()) {
        error_record = MXLoggerError("update write time error:%s\n", file_.error_message().c_str());
        return false;
    }
#endif
    const bool success = mapping_.unmap();
    mmap_ptr_ = mapping_.data();
    if (!success) {
        error_record = MXLoggerError("unmap error:%s\n", mapping_.error_message().c_str());
    }
    return success;
}

bool mmap_sink::mmap_(){
    const bool success = mapping_.map(file_, file_size_);
    mmap_ptr_ = mapping_.data();
    if (!success) {
        error_record = MXLoggerError("map error:%s\n", mapping_.error_message().c_str());
        return false;
    }
    error_record.clear();
    return true;
}

void mmap_sink::flush() {
#if MXLOGGER_MULTIPROCESS
    ipc::scoped_lock lock(process_lock_);
    if (!lock) {
        error_record = MXLoggerError("flush lock error:%s\n", lock.error_message().c_str());
        return;
    }
    transaction_cleanup cleanup{*this};
    if (!is_exit_path()) return;
    if (!refresh_mmap_()) return;
#endif
#ifdef _WIN32
    if (!flush_windows_write_time_()) {
        error_record = MXLoggerError("update write time error:%s\n", file_.error_message().c_str());
        return;
    }
#endif
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
        if (FlushFileBuffers(file_.get()) == 0) {
            error_record = MXLoggerError("[mxlogger_error]FlushFileBuffers error:%lu\n", GetLastError());
            return false;
        }
    }
#else
#if MXLOGGER_MULTIPROCESS
    // Another process may have grown the file beyond our old mapping.
    size_t mapped_size = file_size_;
#else
    size_t mapped_size = get_file_size();
#endif
    if (msync(mmap_ptr_, mapped_size, is_sync ? MS_SYNC : MS_ASYNC) != 0) {

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
