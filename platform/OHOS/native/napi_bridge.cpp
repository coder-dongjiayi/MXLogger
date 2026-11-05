#include "smoke.hpp"
#include "mxlogger_ffi.h"
#include "napi/native_api.h"
#include <exception>
#include <string>

namespace {
napi_value version(napi_env env, napi_callback_info) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, flutter_mxlogger_core_version(), NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value run_smoke(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr, nullptr};
    size_t size = 0;
    bool encrypted = false;
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok || argc != 2 ||
        napi_get_value_string_utf8(env, args[0], nullptr, 0, &size) != napi_ok ||
        napi_get_value_bool(env, args[1], &encrypted) != napi_ok) {
        napi_throw_type_error(env, nullptr, "runSmoke requires (directory: string, encrypted: boolean)");
        return nullptr;
    }
    std::string directory(size + 1, '\0');
    if (napi_get_value_string_utf8(env, args[0], directory.data(), directory.size(), &size) != napi_ok) {
        napi_throw_type_error(env, nullptr, "invalid directory");
        return nullptr;
    }
    directory.resize(size);
    try {
        const auto report = mxlogger_poc::run(directory, encrypted);
        napi_value result = nullptr;
        napi_create_string_utf8(env, report.c_str(), report.size(), &result);
        return result;
    } catch (const std::exception &error) {
        napi_throw_error(env, nullptr, error.what());
        return nullptr;
    }
}

napi_value init(napi_env env, napi_value exports) {
    const napi_property_descriptor properties[] = {
        {"coreVersion", nullptr, version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"runSmoke", nullptr, run_smoke, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
    return exports;
}
napi_module module = {1, 0, nullptr, init, "mxlogger", nullptr, {0}};
}

extern "C" __attribute__((constructor)) void RegisterMXLoggerModule() {
    napi_module_register(&module);
}
