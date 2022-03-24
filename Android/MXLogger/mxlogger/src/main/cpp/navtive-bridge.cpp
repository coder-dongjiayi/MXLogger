//
// Created by 董家祎 on 2022/3/23.
//

#include <jni.h>
#include <string>
#include <cstdint>
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

#define BLINGLOGGER_JNI static
namespace blinglogger{
    static jstring string2jstring(JNIEnv *env, const std::string &str) {
        return env->NewStringUTF(str.c_str());
    }

    BLINGLOGGER_JNI jstring version(JNIEnv *env, jclass type){
        std::string v = "1.2.3";
        return string2jstring(env,v);
    }
}
static JNINativeMethod g_methods[] = {
        {"version", "()Ljava/lang/String;", (void *) blinglogger::version},
};
static int registerNativeMethods(JNIEnv *env, jclass cls) {
    return env->RegisterNatives(cls, g_methods, sizeof(g_methods) / sizeof(g_methods[0]));
}
