//
// Created by 董家祎 on 2022/3/23.
//

#include <jni.h>
#include <string>
#include <cstdint>
#include "mxlogger_manager.hpp"
static JavaVM *g_currentJVM = nullptr;
static jclass g_cls = nullptr;

static int registerNativeMethods(JNIEnv *env, jclass cls);

extern "C" JNIEXPORT JNICALL jint  JNI_OnLoad(JavaVM *vm, void *reserved) {
   g_currentJVM = vm;
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
    return JNI_VERSION_1_6;
}

#define MXLOGGER_JNI static
namespace mxlogger{
    MXLOGGER_JNI  inline log_type _logType(jint logtype);
    MXLOGGER_JNI inline  level::level_enum _level(jint type);

    static jstring string2jstring(JNIEnv *env, const std::string &str) {
        return env->NewStringUTF(str.c_str());
    }
    static std::string jstring2string(JNIEnv *env, jstring str) {
        if (str) {
            const char *kstr = env->GetStringUTFChars(str, nullptr);
            if (kstr) {
                std:: string result(kstr);
                env->ReleaseStringUTFChars(str, kstr);
                return result;
            }
        }
        return "";
    }

    MXLOGGER_JNI jstring version(JNIEnv *env, jclass type){
        std::string v = "0.0.1";
        return string2jstring(env,v);
    }
    MXLOGGER_JNI void native_storagePolicy(JNIEnv *env, jobject obj,jstring policy){
        if (policy == nullptr) return;
        policy::storage_policy  storage_policy = policy::storage_policy::yyyy_MM_dd;

        const char * policy_str = jstring2string(env,policy).c_str();

        if (strcmp("yyyy_MM",policy_str) == 0){
            storage_policy = policy::storage_policy::yyyy_MM;
        }else if(strcmp("yyyy_MM_dd",policy_str)  == 0){
            storage_policy = policy::storage_policy::yyyy_MM_dd;
        }else if (strcmp("yyyy_ww",policy_str) == 0){
            storage_policy = policy::storage_policy::yyyy_ww;
        }else if (strcmp("yyyy_MM_dd_HH",policy_str) == 0){
            storage_policy =  policy::storage_policy::yyyy_MM_dd_HH;
        }
        mx_logger ::instance().set_file_policy(storage_policy);
    }

    MXLOGGER_JNI void jniInitialize(JNIEnv *env, jobject obj,jstring diskCachePath){
        if (diskCachePath == nullptr) return;

        std::string disk_cache_path =jstring2string(env,diskCachePath);

        mx_logger &logger = mx_logger ::instance();
        logger.set_file_dir(disk_cache_path);
    }

    MXLOGGER_JNI void native_log(JNIEnv *env, jobject obj,jint type,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){

        const char  * log_msg = msg == NULL ? nullptr :jstring2string(env,msg).c_str();

        const char  * log_tag = tag == NULL ? nullptr : jstring2string(env,tag).c_str();

        const char  * log_name = name == NULL ? nullptr : jstring2string(env,name).c_str();

        mx_logger::instance().log(_logType(type),_level(level),log_name,log_msg,log_tag,(bool)mainThread);
    }

    MXLOGGER_JNI void native_async_file_log(JNIEnv *env, jobject obj,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){

        const char  * log_msg = msg == NULL ? nullptr :jstring2string(env,msg).c_str();

        const char  * log_tag = tag == NULL ? nullptr : jstring2string(env,tag).c_str();

        const char  * log_name = name == NULL ? nullptr : jstring2string(env,name).c_str();


        mx_logger::instance().log_async_file(_level(level),log_name,log_msg,log_tag,(bool )mainThread);
    }

    MXLOGGER_JNI void native_sync_file_log(JNIEnv *env, jobject obj,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){

        const char  * log_msg = msg == NULL ? nullptr :jstring2string(env,msg).c_str();

        const char  * log_tag = tag == NULL ? nullptr : jstring2string(env,tag).c_str();

        const char  * log_name = name == NULL ? nullptr : jstring2string(env,name).c_str();


        mx_logger::instance().log_sync_file(_level(level),log_name,log_msg,log_tag,(bool )mainThread);
    }

    MXLOGGER_JNI inline log_type _logType(jint type){
        switch (type) {
            case 0:
                return log_type::all;
            case 1:
                return log_type::console;
            case 2:
                return log_type::file;
            default:
                return log_type::all;
        }
    }
    MXLOGGER_JNI inline  level::level_enum _level(jint type){
        switch (type) {
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
    MXLOGGER_JNI void native_consolePattern(JNIEnv *env, jobject obj,jstring pattern){
        if (pattern == nullptr) return;
        std::string  console = jstring2string(env,pattern);

        mx_logger ::instance().set_console_pattern(console);
    }
    MXLOGGER_JNI void native_filePattern(JNIEnv *env, jobject obj,jstring pattern){
        if (pattern == nullptr) return;
        std::string  file = jstring2string(env,pattern);

        mx_logger ::instance().set_file_pattern(file);
    }
    MXLOGGER_JNI void native_consoleEnable(JNIEnv *env, jobject obj,jboolean enable){
        mx_logger ::instance().set_console_enable((bool )enable);
    }
    MXLOGGER_JNI void native_fileEnable(JNIEnv *env, jobject obj,jboolean enable){
        mx_logger ::instance().set_file_enable((bool )enable);
    }

    MXLOGGER_JNI void native_consoleLevel(JNIEnv *env, jobject obj,jint level){
        mx_logger::instance().set_console_level(_level(level));
    }
    MXLOGGER_JNI void native_fileLevel(JNIEnv *env, jobject obj,jint level){
      mx_logger ::instance().set_file_level(_level(level));
    }
    MXLOGGER_JNI void native_fileHeader(JNIEnv *env, jobject obj,jstring file_header){
        std::string file_header_str = jstring2string(env,file_header);

        mx_logger::instance().set_file_header(file_header_str.c_str());
    }
    MXLOGGER_JNI void native_fileName(JNIEnv *env, jobject obj,jstring file_name){
        std::string file_name_str = jstring2string(env,file_name);
        mx_logger::instance().set_file_name(file_name_str.c_str());
    }
    MXLOGGER_JNI void native_maxDiskAge(JNIEnv *env, jobject obj,jlong maxAge){
        mx_logger::instance().set_file_max_age((long )maxAge);
    }
    MXLOGGER_JNI void native_maxDiskSize(JNIEnv *env, jobject obj,jlong maxSize){
        mx_logger::instance().set_file_max_size((long )maxSize);
    }
    MXLOGGER_JNI jlong native_logSize(){
        return  (long )mx_logger::instance().file_size();
    }
    MXLOGGER_JNI jboolean native_isDebugTracking(){
        return (bool )mx_logger::instance().is_debuging();
    }
    MXLOGGER_JNI void native_isAsync(JNIEnv *env, jobject obj,jboolean isAsync){
        mx_logger::instance().set_file_async(isAsync);
    }
    MXLOGGER_JNI void native_removeExpireData(){
        mx_logger::instance().remove_expire_data();
    }

    MXLOGGER_JNI void native_removeAll(){
        mx_logger::instance().remove_all();
    }

}
static JNINativeMethod g_methods[] = {
        {"version", "()Ljava/lang/String;", (void *) mxlogger::version},
        {"jniInitialize","(Ljava/lang/String;)V",(void *)mxlogger::jniInitialize},
        {"native_log","(ILjava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)V",(void *)mxlogger::native_log},
        {"native_async_file_log","(Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)V",(void *)mxlogger::native_async_file_log},
        {"native_sync_file_log","(Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)V",(void *)mxlogger::native_sync_file_log},

        {"native_storagePolicy","(Ljava/lang/String;)V",(void *)mxlogger::native_storagePolicy},
        {"native_consolePattern","(Ljava/lang/String;)V",(void *)mxlogger::native_consolePattern},
        {"native_filePattern","(Ljava/lang/String;)V",(void *)mxlogger::native_filePattern},
        {"native_consoleLevel","(I)V",(void *)mxlogger::native_consoleLevel},
        {"native_fileLevel","(I)V",(void *)mxlogger::native_fileLevel},
        {"native_consoleEnable","(Z)V",(void *)mxlogger::native_consoleEnable},
        {"native_fileEnable","(Z)V",(void *)mxlogger::native_fileEnable},
        {"native_fileHeader","(Ljava/lang/String;)V",(void *)mxlogger::native_fileHeader},
        {"native_fileName","(Ljava/lang/String;)V",(void *)mxlogger::native_fileName},
        {"native_maxDiskAge","(J)V",(void *)mxlogger::native_maxDiskAge},
        {"native_maxDiskSize","(J)V",(void *)mxlogger::native_maxDiskSize},
        {"native_logSize","()J",(void *)mxlogger::native_logSize},
        {"native_isDebugTracking","()Z",(void *)mxlogger::native_isDebugTracking},
        {"native_isAsync","(Z)V",(void *)mxlogger::native_isAsync},
        {"native_removeExpireData","()V",(void *)mxlogger::native_removeExpireData},
        {"native_removeAll","()V",(void *)mxlogger::native_removeAll}


};
static int registerNativeMethods(JNIEnv *env, jclass cls) {
    return env->RegisterNatives(cls, g_methods, sizeof(g_methods) / sizeof(g_methods[0]));
}
