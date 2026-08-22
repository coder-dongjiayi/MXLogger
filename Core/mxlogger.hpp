//
//  mxlog.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef mxlog_hpp
#define mxlog_hpp
#include <string>
#include <stdio.h>
#include <mutex>



namespace mxlogger{
namespace sinks {

class mmap_sink;
}


class mxlogger{
private:

    /// 构造函数：根据磁盘缓存路径、存储策略、文件名、文件头、加密 key 和 iv 创建 logger，并初始化底层 mmap sink
    /// Constructor: create a logger with the disk-cache path, storage policy, file name, file header,
    /// encryption key and iv, and initialize the underlying mmap sink
    mxlogger(const char *diskcache_path,const char* storage_policy,const char* file_name,  const char* file_header, const char* cryptKey, const char* iv);

    /// 析构函数：销毁 logger 对象
    /// Destructor: destroy the logger instance
    ~mxlogger();

    /// 根据 logger_key 从全局实例表中查找并释放对应的 logger 对象
    /// Find the logger in the global instance map by logger_key, then delete and remove it
    static void delete_namespace_(const char* logger_key);

    std::shared_ptr<sinks::mmap_sink> mmap_sink_;

    bool enable_;
    bool enable_console_;


    std::mutex logger_mutex;

    /// 拼接磁盘缓存路径：directory + "/" + ns + "/"，ns 为空时使用 "default"
    /// Build the disk-cache path as directory + "/" + ns + "/"; falls back to "default" when ns is null
    static std::string get_diskcache_path_(const char* ns,const char* directory);

    std::string diskcache_path_;

    std::string logger_key_;



public:


    /// 初始化（或获取）指定命名空间的 logger：同一 ns + directory 只会创建一个实例，已存在时直接返回
    /// Initialize (or fetch) the logger for the given namespace: only one instance is created
    /// per ns + directory; an existing instance is returned directly
    /// @param ns 命名空间 / namespace
    /// @param directory 日志存储根目录 / root directory for log storage
    /// @param storage_policy 文件存储策略 / file storage policy
    /// @param file_name 日志文件名，为空时默认 "mxlog" / log file name, defaults to "mxlog" when null
    /// @param file_header 写入文件头部的自定义信息 / custom header written at the beginning of the file
    /// @param cryptKey AES-CFB-128 加密 key，为空时不加密；16 字节：超出截断，不足补 0
    ///                 / AES-CFB-128 encryption key, no encryption when null;
    ///                 16 bytes: truncated if longer, zero-padded if shorter
    /// @param iv AES-CFB-128 加密向量，为空时默认与 key 相同；16 字节：超出截断，不足补 0
    ///           / AES-CFB-128 initialization vector, defaults to the key when null;
    ///           16 bytes: truncated if longer, zero-padded if shorter
    static mxlogger *initialize_namespace(const char* ns,
                                          const char* directory,
                                          const char* storage_policy,
                                          const char* file_name,
                                          const char* file_header,
                                          const char* cryptKey,
                                          const char* iv);

    /// 根据 ns + directory 释放对应的 logger 对象
    /// Release the logger identified by ns + directory
    static void delete_namespace(const char* ns,const char* directory);

    /// 根据 logger_key 释放对应的 logger 对象
    /// Release the logger identified by logger_key
    static void delete_namespace(const char* logger_key);

    /// 计算 ns + directory 对应的 logger_key（对磁盘缓存路径做 md5）
    /// Compute the logger_key for ns + directory (md5 of the disk-cache path)
    static std::string md5(const char* ns,const char* directory);


    /// 通过 logger_key 返回已存在的 mxlogger 对象，如果不存在则返回 nullptr
    /// Return the existing mxlogger instance for the given logger_key, or nullptr if none exists
    static mxlogger *global_for_loggerKey(const char* logger_key);

    /// 释放全部的 logger 对象并清空全局实例表
    /// Release all logger instances and clear the global instance map
    static void destroy();


    /// 是否开启日志写入，关闭后 log() 直接返回
    /// Enable or disable logging; when disabled, log() returns immediately
    void set_enable(bool enable);

    /// 是否开启控制台输出。
    /// 注意: 发布构建(iOS/macOS的Release/Profile、Linux/Windows的NDEBUG构建)下控制台整段
    /// 被编译期裁掉(见mxlogger_console.hpp的MXLOGGER_CONSOLE_ENABLED)，此时本方法只是记下
    /// 标记，不会有任何输出；Android发的是预编译aar，不参与裁剪，仍是纯运行时开关。
    /// Enable or disable console output.
    /// Note: in release builds (Release/Profile on iOS/macOS, NDEBUG builds on Linux/Windows)
    /// the console is stripped at compile time (see MXLOGGER_CONSOLE_ENABLED in
    /// mxlogger_console.hpp), so this only records the flag and nothing is printed. Android
    /// ships a prebuilt aar, is excluded from stripping and stays purely runtime-gated.
    void set_enable_console(bool enable);

    /// 设置日志文件最大字节数(byte)，0 为不限制；超限清理在调用 remove_expire_data 时执行
    /// Set the maximum total size of log files in bytes, 0 means unlimited;
    /// the over-limit cleanup runs when remove_expire_data is called
    void set_file_max_size(const  long max_size);

    /// 设置日志文件最大存储时长(秒)，0 为不限制；以文件最后修改时间判断是否过期，
    /// 过期文件在调用 remove_expire_data 时删除
    /// Set the maximum age of log files in seconds, 0 means unlimited; expiry is judged
    /// by each file's last-modified time, and expired files are deleted when
    /// remove_expire_data is called
    void set_file_max_age(const  long max_age);

    /// 清理日志文件：先删除过期文件（最后修改时间超过 max_age 的文件），若总大小仍超过
    /// max_size 则从最旧的文件开始继续删除；当前正在写入的文件不会被删除
    /// Clean up log files: first delete expired files (last-modified time older than
    /// max_age), then, if the total size still exceeds max_size, keep deleting from the
    /// oldest file onward; the file currently being written is never deleted
    void remove_expire_data();

    /// 删除所有日志文件
    /// Remove all log files
    void remove_all();

    /// 删除除当前正在写入文件之外的所有日志文件
    /// Remove all log files except the one currently being written
    void remove_before_all();

    /// 返回日志目录已占用的磁盘大小(byte)
    /// Return the total disk size occupied by the log directory in bytes
    long  dir_size();

    /// 设置日志存储等级，低于该等级的日志不会写入
    /// Set the log storage level; logs below this level are not written
    void set_log_level(int level);

    /// 将缓冲区数据强制刷入磁盘，基于 mmap 写入通常不需要手动调用
    /// Force-flush buffered data to disk; rarely needed since writes go through mmap
    void flush();


    /// 返回底层 mmap sink 最近一次的错误描述
    /// Return the latest error description recorded by the underlying mmap sink
    const char* error_desc() const;

    /// 返回日志的磁盘存储路径
    /// Return the disk-cache path where logs are stored
    const char* diskcache_path() const;

    /// 返回 logger_key：由 nameSpace + diskCacheDirectory 做一次 md5 得到，唯一对应一个 logger 对象，
    /// 可通过它操作该 logger
    /// Return the logger_key: the md5 of nameSpace + diskCacheDirectory, uniquely identifying
    /// this logger instance and usable to operate on it
    const char* logger_key() const;

    /// 记录一条日志
    /// Write a log entry
    ///
    /// @return 0 成功  -1 扩容失败  -2 解除映射失败  -3 映射失败
    ///         0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
    ///
    /// @param level 日志等级：0 debug 1 info 2 warn 3 error 4 fatal
    ///              log level: 0 debug, 1 info, 2 warn, 3 error, 4 fatal
    /// @param name 日志名称，为空时默认 "mxlogger" / logger name, defaults to "mxlogger" when null
    /// @param msg 日志信息 / log message
    /// @param tag 标记 / tag
    /// @param is_main_thread 是否在主线程 / whether the call is made on the main thread
    int log(int level,const char* name, const char* msg,const char* tag,bool is_main_thread);




};


}

using mx_logger = typename mxlogger::mxlogger;
#endif /* mxlog_hpp */
