#include "mxlogger_ffi.h"
#if defined(_WIN32)
#include "mxlogger_ffi_memory.hpp"
#include <windows.h>
#include <shlobj.h>
#include <filesystem>
#include <string>
#include <vector>

char* MXLOGGER_FFI_CALL flutter_mxlogger_default_directory() {
    PWSTR folder = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &folder))) return nullptr;
    try {
        std::filesystem::path root(folder);
        CoTaskMemFree(folder);
        folder = nullptr;
        std::vector<wchar_t> module(32768);
        const DWORD length = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
        if (!length || length >= module.size()) return nullptr;
        const auto name = std::filesystem::path(std::wstring(module.data(), length)).stem();
        const auto path = (root / L"MXLogger" / name).u8string();
        return mxlogger_ffi_detail::copy_string(path.c_str());
    } catch (...) { CoTaskMemFree(folder); return nullptr; }
}
#endif
