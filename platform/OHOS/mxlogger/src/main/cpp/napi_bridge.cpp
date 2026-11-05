#include "mxlogger_ohos.h"
#include "napi/native_api.h"
#include <cmath>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
void status(napi_status result) {
    if (result != napi_ok) throw std::invalid_argument("invalid native argument");
}
void native_status() {
    const auto code = mxlogger_ohos_last_error_code();
    if (code) throw std::runtime_error(mxlogger_ohos_last_error());
}
struct Args {
    napi_env env;
    std::vector<napi_value> values;
    Args(napi_env e, napi_callback_info info, size_t expected) : env(e), values(expected) {
        size_t count = expected;
        status(napi_get_cb_info(env, info, &count, values.data(), nullptr, nullptr));
        if (count != expected) throw std::invalid_argument("incorrect argument count");
    }
    std::string string(size_t index) {
        size_t size = 0;
        status(napi_get_value_string_utf8(env, values.at(index), nullptr, 0, &size));
        std::string result(size + 1, '\0');
        status(napi_get_value_string_utf8(env, values[index], result.data(), result.size(), &size));
        result.resize(size);
        if (result.find('\0') != std::string::npos) throw std::invalid_argument("embedded NUL is not supported");
        return result;
    }
    int64_t number(size_t index) {
        double value = 0;
        status(napi_get_value_double(env, values.at(index), &value));
        if (!std::isfinite(value) || std::floor(value) != value || value < 0 || value > 9007199254740991.0)
            throw std::invalid_argument("expected a nonnegative safe integer");
        return static_cast<int64_t>(value);
    }
    void *handle(size_t index = 0) {
        void *value = nullptr;
        status(napi_unwrap(env, values.at(index), &value));
        if (!value) throw std::invalid_argument("invalid logger object");
        return value;
    }
};
template<class F> napi_value call(napi_env env, napi_callback_info info, size_t count, F &&operation) {
    try {
        Args args(env, info, count);
        return operation(args);
    } catch (const std::exception &error) {
        const char *codes[] = {"MXLOGGER_ERROR", "MXLOGGER_ARGUMENT", "MXLOGGER_CLOSED", "MXLOGGER_CONFLICT", "MXLOGGER_IO"};
        const int code = dynamic_cast<const std::invalid_argument *>(&error) ? 1 : mxlogger_ohos_last_error_code();
        napi_throw_error(env, code >= 1 && code <= 4 ? codes[code] : codes[0], error.what());
        return nullptr;
    }
}
napi_value undefined(napi_env env) {
    napi_value result = nullptr;
    status(napi_get_undefined(env, &result));
    return result;
}
napi_value string(napi_env env, const char *text) {
    napi_value result = nullptr;
    status(napi_create_string_utf8(env, text, NAPI_AUTO_LENGTH, &result));
    return result;
}
napi_value owned_string(napi_env env, char *text) {
    std::unique_ptr<char, decltype(&flutter_mxlogger_free_string)> owner(text, flutter_mxlogger_free_string);
    native_status();
    if (!text) throw std::runtime_error("native allocation failed");
    return string(env, text);
}
void finalize(napi_env, void *handle, void *) {
    flutter_mxlogger_release_handle(handle);
}
napi_value object(napi_env env, void *handle) {
    native_status();
    if (!handle) throw std::runtime_error("cannot acquire logger");
    napi_value result = nullptr;
    if (napi_create_object(env, &result) != napi_ok ||
        napi_wrap(env, result, handle, finalize, nullptr, nullptr) != napi_ok) {
        flutter_mxlogger_release_handle(handle);
        throw std::runtime_error("cannot wrap logger");
    }
    napi_value marker = nullptr;
    napi_get_boolean(env, true, &marker);
    napi_set_named_property(env, result, "owned", marker);
    return result;
}
napi_value initialize(napi_env env, napi_callback_info info) {
    return call(env, info, 7, [&](Args &a) {
        const auto ns=a.string(0), dir=a.string(1), policy=a.string(2), filename=a.string(3),
            header=a.string(4), key=a.string(5), iv=a.string(6);
        return object(env, flutter_mxlogger_initialize(ns.c_str(), dir.c_str(), policy.c_str(), filename.c_str(),
            header.empty() ? nullptr : header.c_str(), key.empty() ? nullptr : key.c_str(), iv.empty() ? nullptr : iv.c_str()));
    });
}
napi_value attach(napi_env env, napi_callback_info info) {
    return call(env, info, 1, [&](Args &a) { return object(env, mxlogger_ohos_attach(a.string(0).c_str())); });
}
napi_value version(napi_env env, napi_callback_info info) {
    return call(env, info, 0, [&](Args &) { return string(env, flutter_mxlogger_core_version()); });
}
napi_value log(napi_env env, napi_callback_info info) {
    return call(env, info, 5, [&](Args &a) {
        const auto level = a.number(1);
        if (level > 4) throw std::invalid_argument("level must be 0..4");
        const auto message=a.string(2), name=a.string(3), tag=a.string(4);
        const auto result = flutter_mxlogger_log(a.handle(), name.c_str(), static_cast<int>(level), message.c_str(), tag.c_str());
        native_status();
        napi_value value = nullptr;
        status(napi_create_int32(env, result, &value));
        return value;
    });
}
napi_value token_log(napi_env env, napi_callback_info info) {
    return call(env, info, 5, [&](Args &a) {
        const auto token=a.string(0), message=a.string(2), name=a.string(3), tag=a.string(4);
        const auto level=a.number(1);
        if (level > 4) throw std::invalid_argument("level must be 0..4");
        const auto result=flutter_mxlogger_log_loggerToken(token.c_str(), name.c_str(), static_cast<int>(level), message.c_str(), tag.c_str());
        native_status();
        napi_value value=nullptr;
        status(napi_create_int32(env,result,&value));
        return value;
    });
}
napi_value configure(napi_env env, napi_callback_info info) {
    return call(env, info, 3, [&](Args &a) {
        const auto option=a.number(1), value=a.number(2);
        if (option > 4) throw std::invalid_argument("invalid option");
        mxlogger_ohos_configure(a.handle(), static_cast<int>(option), value);
        native_status(); return undefined(env);
    });
}
napi_value snapshot(napi_env env, napi_callback_info info) {
    return call(env,info,1,[&](Args &a) { return owned_string(env,mxlogger_ohos_snapshot(a.handle())); });
}
napi_value files(napi_env env, napi_callback_info info) {
    return call(env,info,1,[&](Args &a) { return owned_string(env,mxlogger_ohos_files(a.handle())); });
}
napi_value read(napi_env env, napi_callback_info info) {
    return call(env,info,2,[&](Args &a) { return owned_string(env,mxlogger_ohos_read_file(a.handle(),a.string(1).c_str())); });
}
napi_value valid(napi_env env, napi_callback_info info) {
    return call(env,info,1,[&](Args &a) {
        const bool value=mxlogger_ohos_is_valid(a.handle())!=0;
        napi_value result=nullptr; status(napi_get_boolean(env,value,&result)); return result;
    });
}
napi_value destroy(napi_env env, napi_callback_info info) {
    return call(env,info,1,[&](Args &a) { mxlogger_ohos_destroy_handle(a.handle()); native_status(); return undefined(env); });
}
napi_value flush(napi_env env, napi_callback_info info) {
    return call(env,info,1,[&](Args &a) { mxlogger_ohos_flush(a.handle()); native_status(); return undefined(env); });
}
napi_value clean(napi_env env, napi_callback_info info) {
    return call(env,info,2,[&](Args &a) {
        const auto mode=a.number(1);
        if (mode==0) flutter_mxlogger_remove_expire_data(a.handle());
        else if (mode==1) flutter_mxlogger_remove_before_all_data(a.handle());
        else if (mode==2) flutter_mxlogger_remove_all(a.handle());
        else throw std::invalid_argument("invalid cleanup mode");
        native_status(); return undefined(env);
    });
}
napi_value init(napi_env env, napi_value exports) {
    const napi_property_descriptor methods[] = {
        {"initialize",nullptr,initialize,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"attach",nullptr,attach,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"coreVersion",nullptr,version,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"log",nullptr,log,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"logWithToken",nullptr,token_log,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"configure",nullptr,configure,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"snapshot",nullptr,snapshot,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"files",nullptr,files,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"read",nullptr,read,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"isValid",nullptr,valid,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"destroy",nullptr,destroy,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"flush",nullptr,flush,nullptr,nullptr,nullptr,napi_default,nullptr},
        {"clean",nullptr,clean,nullptr,nullptr,nullptr,napi_default,nullptr}
    };
    napi_define_properties(env,exports,sizeof(methods)/sizeof(methods[0]),methods);
    return exports;
}
napi_module module={1,0,nullptr,init,"mxlogger",nullptr,{0}};
}
extern "C" __attribute__((constructor)) void RegisterMXLoggerModule() { napi_module_register(&module); }
