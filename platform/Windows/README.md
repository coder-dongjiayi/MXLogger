# MXLogger Windows C++ SDK

原生 C++17 SDK，当前 Core 版本为 **2.3.0**，支持 Windows 10/11 x64。
NuGet 包 ID 为 `MXLogger.Native`；vcpkg port 名为 `mxlogger`。
源码、NuGet 和 vcpkg 使用相同的 Core。NuGet 另附供 Flutter/Dart 使用的 C ABI DLL，不包含 .NET 封装。

## NuGet 接入

手动运行仓库的 `verify-logger` CI。全部平台回归通过后，`3. Windows SDK (NuGet + vcpkg)`
任务构建、校验并上传 `MXLogger.Native.2.3.0.nupkg`。该文件可直接作为 NuGet 本地源中的包。
目前不会自动向 nuget.org 发布；仓库中的构建配置不代表包已上架公共源。

1. 下载 nupkg，放入一个文件夹，例如 `D:\NuGetFeed`，无需解压。
2. 在 Visual Studio「工具 → NuGet 包管理器 → 程序包管理器设置 → 程序包源」添加此目录。
3. 在 C++ 项目中选择 x64，再从该源安装 `MXLogger.Native` 2.3.0。

也可在 Visual Studio 的程序包管理器控制台中执行：

```powershell
Install-Package MXLogger.Native -Version 2.3.0 -Source D:\NuGetFeed
```

NuGet 自动导入原生 `.targets`，添加公开头文件和对应的静态库。
使用原生 C++ 静态库时，不需要手动复制 `.lib`，也不需要随应用分发 MXLogger DLL。
源码示例：

```cpp
#include <mxlogger.hpp>
#include <mxlogger_util.hpp>

const char* version = mx_logger::version(); // "2.3.0"
auto* logger = mx_logger::initialize_namespace(
    "my.app", "C:/MyApp/Logs", "yyyy_MM_dd", "app", nullptr, nullptr, nullptr);
if (logger) {
    logger->log(1, "App", "Hello from Windows", "demo", true);
    logger->flush();
    mx_logger::destroy();
}
```

示例中的目录需替换为应用有写入权限的目录。使用 Visual Studio 2022 / v143 或兼容的更新工具链，
消费预编译库的 MSVC 工具版本应不早于构建该包的版本。SDK 提供：

| 工程运行库 | Debug | Release |
|---|---|---|
| 动态 CRT（默认） | `/MDd` | `/MD` |
| 静态 CRT | `/MTd` | `/MT` |

两个配置在同一个 NuGet 包中。默认根据 `UseDebugLibraries` 自动选择 Debug / Release，
没有该属性时以配置名 `Debug` 为回退依据；默认选择 MD 系列。
使用 MT 系列的项目，在 `.vcxproj` 的属性组中设置：

```xml
<PropertyGroup>
  <MXLoggerRuntimeLibrary>MT</MXLoggerRuntimeLibrary>
</PropertyGroup>
```

项目原有的「C/C++ → 代码生成 → 运行库」也应设为相应的 `/MTd` 或 `/MT`。
SDK 不覆盖工程的 CRT 设置，发现不匹配会明确报错。
自定义配置还可设置 `MXLoggerUseDebugLibraries` 为 `true` / `false`。
包会在编译前为未设置、`Default` 或 C++14 的源文件启用 C++17，并保留 C++20 等更新标准。
该规则同样覆盖源文件单独设置的语言标准；打包 CI 会校验这些配置，再执行真实消费工程编译。

## 本地生成 NuGet 包

在 Windows 安装 VS 2022 C++ 桌面工具（v143）、CMake、PowerShell 7 和 NuGet CLI 后执行：

```powershell
pwsh -File scripts/build_windows_nuget.ps1
```

输出为 `build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg`，日志在 `build/windows-sdk/logs/`。
脚本先跑 MD / MT × Debug / Release 的 Core 测试，再校验安装后的 CMake SDK，最后制作 NuGet 包。
随后从本地源还原该包，使用独立 `.vcxproj` 验证四种配置的版本查询、加密写入和解密读取，
并检查 CRT 不匹配时能否正确拒绝构建。它不会发布包。

## Flutter 使用预编译 DLL

同一个 nupkg 包含 `build/native/ffi/x64/{Debug,Release}/mxlogger_ffi.dll`、
`manifest.json`（Core/ABI 版本、架构、哈希及本地源码来源）和 `build/native/include/mxlogger_ffi.h`。
DLL 使用静态 CRT，字符串、数组由 DLL 的配对释放函数回收；调用方不能用自己的 `free` 释放。
原生 C++ 静态库接入保持原有方式，不会自动链接或复制这份 FFI DLL。

无需自己有 Windows 电脑：CI 在 Windows 构建并执行真实 Dart FFI 测试。
Mac 下载 nupkg 后，在仓库根目录执行即可给 Flutter 准备 DLL：

```bash
python3 scripts/prepare_flutter_windows.py --package /path/to/MXLogger.Native.2.3.0.nupkg
python3 scripts/prepare_flutter_windows.py --check
```

输出到 `platform/flutter_mxlogger/windows/bin/x64/`，Flutter CMake 只校验和复制二进制。
发布 pub 前需准备这一步，`.pubignore` 会把 DLL 带入包；Windows 消费方不需要 NuGet 或 Core 源码。
也可直接下载 CI 的 `flutter_mxlogger-windows-prebuilt` 插件包。
以后 Core 有变动，需重新从 CI 获取 nupkg 并导入，不能只修改源码后沿用旧 DLL。

## vcpkg 接入

当前提供仓库内的 **overlay port**，直接编译相邻的 Core 源码；尚未提交到 vcpkg 公共 registry。
请保留完整 MXLogger checkout，不能只复制 port 子目录。
在不含 `vcpkg.json` 的目录执行 classic 模式安装，例如：

```powershell
vcpkg install mxlogger:x64-windows --overlay-ports=D:/src/MXLogger/platform/Windows/vcpkg/ports --no-binarycaching
# 使用静态 CRT 的工程改为 mxlogger:x64-windows-static
```

两个 triplet 都提供静态 MXLogger 库，CRT 分别为 MD / MT 系列。
manifest 模式可在工程中添加：

```json
{ "dependencies": ["mxlogger"] }
```

并在 `vcpkg-configuration.json` 中设置 overlay 路径：

```json
{ "overlay-ports": ["../MXLogger/platform/Windows/vcpkg/ports"] }
```

CMake 工程使用相同的公开 target：

```cmake
find_package(MXLoggerCore 2.3 CONFIG REQUIRED)
target_link_libraries(MyApp PRIVATE MXLogger::Core)
```

配置时传入 vcpkg toolchain 和与工程 CRT 匹配的 triplet。MT 工程也应显式设置 CMake 的
`CMAKE_MSVC_RUNTIME_LIBRARY` 为 `MultiThreaded$<$<CONFIG:Debug>:Debug>`，使用 CMake 3.20+。

该 overlay 使用本地源码，测试同版本的修改时请禁用二进制缓存，并移除已安装的 mxlogger 后重新安装，
避免复用旧源码的产物。CI 使用独立安装目录并禁用缓存验证两种 triplet：

```powershell
pwsh -File scripts/verify_windows_vcpkg.ps1 -VcpkgRoot C:/vcpkg
```

## 普通 CMake SDK 与版本维护

不使用包管理器时，也可自行安装 Core：

```powershell
cmake -S Core -B build/core-sdk -A x64 -DMXLOGGER_INSTALL=ON
cmake --build build/core-sdk --config Debug --parallel
cmake --install build/core-sdk --config Debug --prefix D:/MXLoggerSDK
cmake --build build/core-sdk --config Release --parallel
cmake --install build/core-sdk --config Release --prefix D:/MXLoggerSDK
```

消费工程设置 `CMAKE_PREFIX_PATH=D:/MXLoggerSDK` 后即可 `find_package(MXLoggerCore CONFIG REQUIRED)`。
Debug 和 Release 的库分别为 `MXLoggerCored.lib` / `MXLoggerCore.lib`；CMake 自动选择。
Core 原有源码接入方式也继续可用。

`Core/mxlogger_version.hpp` 是 Core API、CMake 和 NuGet 的版本来源。
升级时同时更新 overlay 的 `vcpkg.json`；版本不一致时 port 会拒绝构建。
发布到 nuget.org 之前，先完成 CI 的真实 Windows 验证并确认包 ID 的所有权，再使用自己的 API Key 发布：

```powershell
nuget push build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg -Source https://api.nuget.org/v3/index.json -ApiKey $env:NUGET_API_KEY
```

NuGet 的原生包布局与 vcpkg overlay 的说明见 [NuGet 文档](https://learn.microsoft.com/en-us/nuget/guides/native-packages)
和 [vcpkg 文档](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports)。
