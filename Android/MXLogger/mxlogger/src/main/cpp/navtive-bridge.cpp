//
// Created by 董家祎 on 2022/3/23.
//

#include <jni.h>
#include <string>
#include <cstdint>
#include "mxlogger.hpp"
#include "mxlogger_util.hpp"
#include <vector>
#include <map>
static jclass g_cls = nullptr;

static int registerNativeMethods(JNIEnv *env, jclass cls);

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

    return JNI_VERSION_1_6;
}

#define MXLOGGER_JNI static
namespace mxlogger{


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


    MXLOGGER_JNI jstring native_diskcache_path(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        const char * path = logger -> diskcache_path();
       return string2jstring(env,path);
    }


    MXLOGGER_JNI jstring  native_loggerKey(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        return string2jstring(env,logger ->logger_key());
    }


    MXLOGGER_JNI void native_log(JNIEnv *env, jobject obj,jlong handle,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){

        const char  * log_msg = msg == NULL ? nullptr :jstring2string(env,msg).c_str();

        const char  * log_tag = tag == NULL ? nullptr : jstring2string(env,tag).c_str();

        const char  * log_name = name == NULL ? nullptr : jstring2string(env,name).c_str();
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger ->log(level,log_name,log_msg,log_tag,mainThread);

    }

    MXLOGGER_JNI void native_log_loggerKey(JNIEnv *env, jobject obj,jstring loggerKey,jstring name,jint level,jstring msg,jstring tag,jboolean mainThread){
        const char  * log_msg = msg == NULL ? nullptr :jstring2string(env,msg).c_str();

        const char  * log_tag = tag == NULL ? nullptr : jstring2string(env,tag).c_str();

        const char  * log_name = name == NULL ? nullptr : jstring2string(env,name).c_str();

        const char  * logger_key = jstring2string(env,loggerKey).c_str();

        mx_logger *logger = mx_logger ::global_for_loggerKey(logger_key);
        if(logger != nullptr){
            logger ->log(level,log_name,log_msg,log_tag,mainThread);
        }

    }

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

        std::string nsStr = jstring2string(env,ns);
        std::string directoryStr = jstring2string(env,directory);

        const char * store_policy = storagePolicy== nullptr ? nullptr :  jstring2string(env,storagePolicy).data();
        const char * file_name = fileName == nullptr ? nullptr : jstring2string(env,fileName).data();
        const char  * crypt_key = cryptKey == nullptr ? nullptr : jstring2string(env,cryptKey).data();
        const char  * iv_ = iv == nullptr ? nullptr : jstring2string(env,iv).data();
        const char * file_header = fileHeader == nullptr ? nullptr : jstring2string(env,fileHeader).data();
        mxlogger * logger =   mx_logger ::initialize_namespace(nsStr.data(),directoryStr.data(),store_policy,file_name,file_header,crypt_key,iv_);
        return jlong (logger);



    }
    MXLOGGER_JNI jobjectArray  native_logFiles(JNIEnv *env, jobject obj,jlong handle){

//        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
//
//        std::vector<std::map<std::string, std::string>> destination;
//
//        util::mxlogger_util::select_logfiles_dir(logger->diskcache_path(),&destination);
//
//
//        jclass hasClass= env->FindClass("java/util/HashMap");
//
//        jobjectArray array = env->NewObjectArray(destination.size(),hasClass,NULL);
//
//        for (int i = 0; i < destination.size(); ++i) {
//            std::map<std::string, std::string> map = destination[i];
//            std::string  name = map["name"];
//            std::string  size = map["size"];
//            std::string  last_timestamp = map["last_timestamp"];
//            std::string  create_timestamp = map["create_timestamp"];
//
//            jclass hashMapClass= env->FindClass("java/util/HashMap");
//            jmethodID hashMapInit = env->GetMethodID(hashMapClass, "<init>", "(I)V");
//            jobject hashMapObj = env->NewObject(hashMapClass, hashMapInit,4);
//            jmethodID hashMapPut = env->GetMethodID(hashMapClass, "put",
//                                                    "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");
//            for (const auto& it : map) {
//                env->CallObjectMethod(hashMapObj, hashMapPut,
//                                      env->NewStringUTF(it.first.c_str()),
//                                      env->NewStringUTF(it.second.c_str()));
//            }
//
//            env->SetObjectArrayElement(array,i,hashMapClass);
//        }

        return nullptr;

    }
    MXLOGGER_JNI void native_destroy_loggerKey(JNIEnv *env, jobject obj,jstring loggerKey){
        std::string loggerKeyStr =jstring2string(env,loggerKey);
        mx_logger::delete_namespace(loggerKeyStr.data());
    }

    MXLOGGER_JNI void native_destroy(JNIEnv *env, jobject obj,jstring ns,jstring directory){
        std::string nsStr =jstring2string(env,ns);
        std::string directoryStr =jstring2string(env,directory);
        mx_logger::delete_namespace(nsStr.data(),directoryStr.data());
    }


    MXLOGGER_JNI void native_consoleEnable(JNIEnv *env, jobject obj,jlong handle,jboolean enable){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
       logger ->set_enable_console(enable);
    }



    MXLOGGER_JNI void native_fileLevel(JNIEnv *env, jobject obj,jlong handle,jint level){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_file_level(level);
    }

    MXLOGGER_JNI void native_maxDiskAge(JNIEnv *env, jobject obj,jlong handle,jlong maxAge){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_file_max_age(maxAge);
    }
    MXLOGGER_JNI void native_maxDiskSize(JNIEnv *env, jobject obj,jlong handle,jlong maxSize){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> set_file_max_size(maxSize);
    }
    MXLOGGER_JNI jlong native_logSize(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        return  (long )logger->dir_size();
    }



    MXLOGGER_JNI void native_removeExpireData(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_expire_data();
    }

    MXLOGGER_JNI void native_removeAll(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_all();
    }
    MXLOGGER_JNI void native_removeBeforeAll(JNIEnv *env, jobject obj,jlong handle){
        mx_logger *logger = reinterpret_cast<mx_logger *>(handle);
        logger -> remove_before_all();
    }

}
static JNINativeMethod g_methods[] = {

        {"jniInitialize","(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)J",(void *)mxlogger::jniInitialize},
        {"native_fileLevel","(JI)V",(void *)mxlogger::native_fileLevel},
        {"native_consoleEnable","(JZ)V",(void *)mxlogger::native_consoleEnable},
        {"native_maxDiskAge","(JJ)V",(void *)mxlogger::native_maxDiskAge},
        {"native_maxDiskSize","(JJ)V",(void *)mxlogger::native_maxDiskSize},
        {"native_logSize","(J)J",(void *)mxlogger::native_logSize},
        {"native_diskcache_path","(J)Ljava/lang/String;",(void *)mxlogger::native_diskcache_path},
        {"native_removeExpireData","(J)V",(void *)mxlogger::native_removeExpireData},
        {"native_removeAll","(J)V",(void *)mxlogger::native_removeAll},
        {"native_removeBeforeAll","(J)V",(void *)mxlogger::native_removeBeforeAll},
        {"native_loggerKey","(J)Ljava/lang/String;",(void *)mxlogger::native_loggerKey},
        {"native_log","(JLjava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)V",(void *)mxlogger::native_log},
        {"native_log_loggerKey","(Ljava/lang/String;Ljava/lang/String;ILjava/lang/String;Ljava/lang/String;Z)V",(void *)mxlogger::native_log_loggerKey},
        {"native_destroy","(Ljava/lang/String;Ljava/lang/String;)V",(void *)mxlogger::native_destroy},
        {"native_destroy_loggerKey","(Ljava/lang/String;)V",(void *)mxlogger::native_destroy_loggerKey},
//        {"native_logFiles","(J)Ljava/lang/String;",(void*)mxlogger::native_logFiles}


};
static int registerNativeMethods(JNIEnv *env, jclass cls) {
    jint n =  sizeof(g_methods) / sizeof(g_methods[0]);
    jint  r = env->RegisterNatives(cls, g_methods, n);
    return r;
}
