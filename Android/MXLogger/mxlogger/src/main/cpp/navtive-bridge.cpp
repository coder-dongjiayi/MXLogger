//
// Created by 董家祎 on 2022/3/23.
//
// JNI桥接层: 将Java侧 com.dongjiayi.mxlogger.MXLogger 的native方法绑定到C++核心mxlogger
// JNI bridge: binds the native methods of com.dongjiayi.mxlogger.MXLogger (Java side)
// to the C++ mxlogger core
//

#include <jni.h>
#include <string>
#include <cstdint>
#include "mxlogger.hpp"
#include "debug_log.hpp"
#include "mxlogger_util.hpp"
#include "json/cJSON.h"
#include <vector>
#include <map>
#ifdef  __ANDROID__
#include <android/log.h>
#endif
static jclass g_cls = nullptr;
static jfieldID g_fileID = nullptr;
static int registerNativeMethods(JNIEnv *env, jclass cls);

/// JNI入口: so加载时被调用，查找MXLogger类并注册全部native方法，
/// 同时缓存nativeHandle字段ID；任一步失败返回负值使加载失败
/// JNI entry point: called when the .so is loaded — finds the MXLogger class,
/// registers all native methods and caches the nativeHandle field ID;
/// returns a negative value to fail the load if any step fails
extern "C" JNIEXPORT JNICALL jint  JNI_OnLoad(JavaVM *vm, void *reserved) {

    JNIEnv *env;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return -1;
    }
    if (g_cls) {
        env->DeleteGlobalRef(g_cls);
    }
    static const char *clsName = "com/dongjiayi/mxlogger/MXLogger";

    jclass instance = env->FindClass(clsName);
    if (!instance) {

        return -2;
    }
    g_cls = reinterpret_cast<jclass>(env->NewGlobalRef(instance));
    if (!g_cls) {
        return -3;
    }
    int ret = registerNativeMethods(env, g_cls);
    if (ret != 0) {

        return -4;
    }
    g_fileID = env->GetFieldID(g_cls, "nativeHandle", "J");
    if(!g_fileID){
        return -5;
    }
    return JNI_VERSION_1_6;
}

#define MXLOGGER_JNI static
namespace mxlogger{


    /// 将std::string转成jstring
    /// Convert a std::string into a jstring
    static jstring string2jstring(JNIEnv *env, const std::string &str) {
        return env->NewStringUTF(str.c_str());
    }


    /// 获取日志文件磁盘缓存目录
    /// Get the disk-cache directory of the log files
    MXLOGGER_JNI jstring native_diskcache_path(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        const char * path = logger -> diskcache_path();
       return string2jstring(env,path);
    }


    /// 获取logger的唯一标识loggerKey (nameSpace+diskCacheDirectory的md5值)
    /// Get the logger's unique key (the md5 of nameSpace + diskCacheDirectory)
    MXLOGGER_JNI jstring  native_loggerKey(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        return string2jstring(env,logger ->logger_key());
    }

    /// 获取最近一次写入失败的错误信息
    /// Get the most recent write-error description
    MXLOGGER_JNI jstring  native_errorDesc(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        return string2jstring(env,logger ->error_desc());
    }


    /// 通过句柄写入日志
    /// 返回 0成功 -1扩容失败 -2解除映射失败 -3映射失败
    /// Write a log entry via the handle
    /// Returns 0 success, -1 file expansion failed, -2 unmap failed, -3 mmap failed
    MXLOGGER_JNI jint native_log(JNIEnv *env, jobject obj,jlong handle,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){

        const char  * log_tag = tag == NULL ? nullptr :  env->GetStringUTFChars(tag, nullptr);

        const char  * log_name = name == NULL ? nullptr :env->GetStringUTFChars(name, nullptr);

        const char  * log_msg = msg == NULL ? nullptr : env->GetStringUTFChars(msg, nullptr);



        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);

        int result = logger ->log(level,log_name,log_msg,log_tag,mainThread);

        /// GetStringUTFChars每次都会malloc一份拷贝，必须配对释放，
        /// 否则每写一条日志泄漏一次内存；log()是同步调用，返回后即可安全释放
        /// GetStringUTFChars mallocs a copy every call and must be released in pairs,
        /// otherwise every log entry leaks memory; log() is synchronous, so releasing
        /// after it returns is safe
        if (log_tag != nullptr) env->ReleaseStringUTFChars(tag, log_tag);
        if (log_name != nullptr) env->ReleaseStringUTFChars(name, log_name);
        if (log_msg != nullptr) env->ReleaseStringUTFChars(msg, log_msg);

        return result;

    }

    /// 通过loggerKey写入日志: 查找已初始化的logger对象，不存在时静默返回0不报错
    /// Write a log entry via loggerKey: looks up the already-initialized logger;
    /// silently returns 0 (no error) when no logger matches the key
    MXLOGGER_JNI jint native_log_loggerKey(JNIEnv *env, jobject obj,jstring loggerKey,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){
        const char  * log_msg = msg == NULL ? nullptr : env->GetStringUTFChars(msg, nullptr);

        const char  * log_tag = tag == NULL ? nullptr : env->GetStringUTFChars(tag, nullptr);

        const char  * log_name = name == NULL ? nullptr : env->GetStringUTFChars(name, nullptr);

        const char  * logger_key = env->GetStringUTFChars(loggerKey, nullptr);

        mx_logger *logger = mx_logger ::global_for_loggerKey(logger_key);

        int result = 0;
        if(logger != nullptr){
            result = logger ->log(level,log_name,log_msg,log_tag,mainThread);
        }

        /// 与native_log相同：GetStringUTFChars的拷贝必须配对释放，防止每次调用泄漏
        /// Same as native_log: the GetStringUTFChars copies must be released in pairs
        /// to avoid leaking on every call
        if (log_msg != nullptr) env->ReleaseStringUTFChars(msg, log_msg);
        if (log_tag != nullptr) env->ReleaseStringUTFChars(tag, log_tag);
        if (log_name != nullptr) env->ReleaseStringUTFChars(name, log_name);
        env->ReleaseStringUTFChars(loggerKey, logger_key);

        return  result;
    }

    /// 初始化logger: 创建(或复用)C++核心对象，返回其指针作为Java侧持有的句柄，
    /// ns或directory为空时返回0
    /// Initialize the logger: create (or reuse) the C++ core instance and return its
    /// pointer as the handle held by the Java side; returns 0 when ns or directory is null
    MXLOGGER_JNI jlong jniInitialize(JNIEnv *env,
                                     jobject obj,
                                     jstring ns,
                                     jstring directory,
                                     jstring storagePolicy,
                                     jstring fileName,
                                     jstring  fileHeader,
                                     jstring cryptKey,
                                     jstring  iv
                                     ){


        if (ns == nullptr || directory == nullptr) return 0;




        const char * nsStr = env->GetStringUTFChars(ns, nullptr);
        const char * directoryStr = env->GetStringUTFChars(directory, nullptr);
        const char * store_policy = storagePolicy== nullptr ? nullptr :  env->GetStringUTFChars(storagePolicy, nullptr);
        const char * file_name = fileName == nullptr ? nullptr : env->GetStringUTFChars(fileName, nullptr);
        const char  * crypt_key_ = cryptKey == nullptr ? nullptr : env->GetStringUTFChars(cryptKey, nullptr);
        const char  * iv_ = iv == nullptr ? nullptr : env->GetStringUTFChars(iv, nullptr);
        const char * file_header = fileHeader == nullptr ? nullptr : env->GetStringUTFChars(fileHeader, nullptr);


       mxlogger * logger =   mx_logger ::initialize_namespace(nsStr,directoryStr,store_policy,file_name,file_header,crypt_key_,iv_);

        /// initialize_namespace内部对所有参数做了拷贝(std::string/密钥memcpy)，
        /// 返回后即可释放GetStringUTFChars分配的拷贝，防止泄漏
        /// initialize_namespace copies every parameter internally (std::string /
        /// key memcpy), so the GetStringUTFChars copies can be released here
        env->ReleaseStringUTFChars(ns, nsStr);
        env->ReleaseStringUTFChars(directory, directoryStr);
        if (store_policy != nullptr) env->ReleaseStringUTFChars(storagePolicy, store_policy);
        if (file_name != nullptr) env->ReleaseStringUTFChars(fileName, file_name);
        if (crypt_key_ != nullptr) env->ReleaseStringUTFChars(cryptKey, crypt_key_);
        if (iv_ != nullptr) env->ReleaseStringUTFChars(iv, iv_);
        if (file_header != nullptr) env->ReleaseStringUTFChars(fileHeader, file_header);

       return jlong (logger);


    }

    /// 将map序列化成JSON字符串放入String[] 供Java侧解析
    /// Serialize a map into a JSON jstring so the Java side can parse it from a String[]
    static jstring map2json_jstring(JNIEnv *env, const std::map<std::string, std::string> &map){
        cJSON *item = cJSON_CreateObject();
        for (const auto &entry : map) {
            cJSON_AddStringToObject(item, entry.first.c_str(), entry.second.c_str());
        }
        char *json = cJSON_PrintUnformatted(item);
        cJSON_Delete(item);
        if (json == nullptr) return nullptr;
        jstring jstr = env->NewStringUTF(json);
        free(json);
        return jstr;
    }

    /// 获取日志文件列表 返回JSON字符串数组 字段: name/size/last_timestamp/create_timestamp
    /// Get the list of log files as a JSON string array with fields:
    /// name/size/last_timestamp/create_timestamp
    MXLOGGER_JNI jobjectArray  native_logFiles(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);

        std::vector<std::map<std::string, std::string>> destination;
        util::mxlogger_util::select_logfiles_dir(logger->diskcache_path(),&destination);

        jclass stringCls = env->FindClass("java/lang/String");
        jobjectArray array = env->NewObjectArray((jsize)destination.size(), stringCls, nullptr);
        for (int i = 0; i < (int)destination.size(); ++i) {
            jstring jstr = map2json_jstring(env, destination[i]);
            if (jstr != nullptr) {
                env->SetObjectArrayElement(array, i, jstr);
                env->DeleteLocalRef(jstr);
            }
        }
        return array;
    }

    /// 解析(解密)日志文件 返回JSON字符串数组
    /// 与iOS selectWithDiskCacheFilePath行为对齐: 倒序返回 最新的记录在前
    /// 字段: name/msg/tag/level/timestamp/is_main_thread/thread_id/error_code
    /// Parse (and decrypt) a log file, returning entries as a JSON string array.
    /// Consistent with iOS selectWithDiskCacheFilePath: newest entries first.
    /// Fields: name/msg/tag/level/timestamp/is_main_thread/thread_id/error_code
    MXLOGGER_JNI jobjectArray native_selectLogMsg(JNIEnv *env, jclass cls, jstring filePath, jstring cryptKey, jstring iv){
        if (filePath == nullptr) return nullptr;
        const char *path = env->GetStringUTFChars(filePath, nullptr);
        const char *key = cryptKey == nullptr ? nullptr : env->GetStringUTFChars(cryptKey, nullptr);
        const char *iv_ = iv == nullptr ? nullptr : env->GetStringUTFChars(iv, nullptr);

        std::vector<std::map<std::string, std::string>> destination;
        util::mxlogger_util::select_log_form_path(path, &destination, key, iv_);

        jclass stringCls = env->FindClass("java/lang/String");
        jsize count = (jsize)destination.size();
        jobjectArray array = env->NewObjectArray(count, stringCls, nullptr);
        for (int i = 0; i < count; ++i) {
            jstring jstr = map2json_jstring(env, destination[count - 1 - i]);
            if (jstr != nullptr) {
                env->SetObjectArrayElement(array, i, jstr);
                env->DeleteLocalRef(jstr);
            }
        }

        env->ReleaseStringUTFChars(filePath, path);
        if (key != nullptr) env->ReleaseStringUTFChars(cryptKey, key);
        if (iv_ != nullptr) env->ReleaseStringUTFChars(iv, iv_);
        return array;
    }

    /// 通过loggerKey销毁C++对象
    /// 注意: Java侧是static native方法, JNI第二个参数实际是jclass而非实例对象,
    /// 不能对其SetLongField实例字段(CheckJNI下会直接abort), 句柄失效由Java侧自行约束
    /// Destroy the C++ instance by loggerKey.
    /// Note: the Java method is static native, so the second JNI parameter is a jclass,
    /// not an instance — calling SetLongField on it would abort under CheckJNI;
    /// invalidating the handle is the Java side's responsibility
    MXLOGGER_JNI void native_destroy_loggerKey(JNIEnv *env, jclass cls,jstring loggerKey){
        const char  * loggerKeyStr =env->GetStringUTFChars(loggerKey, nullptr);
        mx_logger::delete_namespace(loggerKeyStr);
        env->ReleaseStringUTFChars(loggerKey, loggerKeyStr);
    }

    /// 通过nameSpace+diskCacheDirectory销毁C++对象
    /// Destroy the C++ instance by nameSpace + diskCacheDirectory
    MXLOGGER_JNI void native_destroy(JNIEnv *env, jclass cls,jstring ns,jstring directory){


        const char  * nsStr = env->GetStringUTFChars(ns, nullptr);

        const char  * directoryStr = env->GetStringUTFChars(directory, nullptr);
        mx_logger::delete_namespace(nsStr,directoryStr);
        env->ReleaseStringUTFChars(ns, nsStr);
        env->ReleaseStringUTFChars(directory, directoryStr);
    }


    /// 开启/关闭native侧控制台输出
    /// Enable or disable native-side console output
    MXLOGGER_JNI void native_consoleEnable(JNIEnv *env, jobject obj,jlong handle,jboolean enable){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
       logger ->set_enable_console(enable);
    }


    /// 设置写入文件的日志等级 低于该等级的日志不会写入
    /// Set the minimum level written to file; logs below this level are not written
    MXLOGGER_JNI void native_level(JNIEnv *env, jobject obj,jlong handle,jint level){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_log_level(level);
    }

    /// 设置日志文件最大存储时长(秒)
    /// Set the maximum age of log files in seconds
    MXLOGGER_JNI void native_maxDiskAge(JNIEnv *env, jobject obj,jlong handle,jlong maxAge){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_file_max_age(maxAge);
    }

    /// 设置日志文件最大字节数(byte)
    /// Set the maximum total size of log files in bytes
    MXLOGGER_JNI void native_maxDiskSize(JNIEnv *env, jobject obj,jlong handle,jlong maxSize){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_file_max_size(maxSize);
    }

    /// 获取存储的日志大小(byte)
    /// Get the total size of stored logs in bytes
    MXLOGGER_JNI jlong native_logSize(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        return  (long )logger->dir_size();
    }


    /// 清理过期日志文件
    /// Remove expired log files
    MXLOGGER_JNI void native_removeExpireData(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_expire_data();
    }

    /// 删除所有日志文件
    /// Remove all log files
    MXLOGGER_JNI void native_removeAll(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_all();
    }

    /// 删除除当前正在写入文件之外的所有日志文件
    /// Remove all log files except the one currently being written
    MXLOGGER_JNI void native_removeBeforeAll(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_before_all();
    }

}

/// Java native方法与C++函数的映射表 (方法名/JNI签名/函数指针)
/// Mapping table between Java native methods and C++ functions (name / JNI signature / pointer)
static JNINativeMethod g_methods[] = {

        {"jniInitialize","(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)J",(void *)mxlogger::jniInitialize},
        {"native_level","(JI)V",(void *)mxlogger::native_level},
        {"native_consoleEnable","(JZ)V",(void *)mxlogger::native_consoleEnable},
        {"native_maxDiskAge","(JJ)V",(void *)mxlogger::native_maxDiskAge},
        {"native_maxDiskSize","(JJ)V",(void *)mxlogger::native_maxDiskSize},
        {"native_logSize","(J)J",(void *)mxlogger::native_logSize},
        {"native_diskcache_path","(J)Ljava/lang/String;",(void *)mxlogger::native_diskcache_path},
        {"native_removeExpireData","(J)V",(void *)mxlogger::native_removeExpireData},
        {"native_removeAll","(J)V",(void *)mxlogger::native_removeAll},
        {"native_removeBeforeAll","(J)V",(void *)mxlogger::native_removeBeforeAll},
        {"native_errorDesc","(J)Ljava/lang/String;",(void*)mxlogger::native_errorDesc},
        {"native_loggerKey","(J)Ljava/lang/String;",(void *)mxlogger::native_loggerKey},
        {"native_log","(JLjava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)I",(void *)mxlogger::native_log},
        {"native_log_loggerKey","(Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)I",(void *)mxlogger::native_log_loggerKey},
        {"native_destroy","(Ljava/lang/String;Ljava/lang/String;)V",(void *)mxlogger::native_destroy},
        {"native_destroy_loggerKey","(Ljava/lang/String;)V",(void *)mxlogger::native_destroy_loggerKey},
        {"native_logFiles","(J)[Ljava/lang/String;",(void*)mxlogger::native_logFiles},
        {"native_selectLogMsg","(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)[Ljava/lang/String;",(void*)mxlogger::native_selectLogMsg}
};

/// 批量注册g_methods中的native方法到MXLogger类
/// Register all native methods in g_methods onto the MXLogger class
static int registerNativeMethods(JNIEnv *env, jclass cls) {
    jint n =  sizeof(g_methods) / sizeof(g_methods[0]);
    jint  r = env->RegisterNatives(cls, g_methods, n);
    return r;
}
