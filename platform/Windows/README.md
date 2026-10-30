# MXLogger Windows C++ SDK

English | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md)

Native **C++17** SDK for **Windows 10/11 x64**, using Core **2.3.0**.
The NuGet package ID is `MXLogger.Native`; the vcpkg port is `mxlogger`.
Both use the same Core. The NuGet package also contains precompiled C ABI DLLs
for Flutter/Dart; it does not provide a .NET wrapper.

## Install from a local NuGet feed

Manually run `verify-logger`. After all platform API tests pass, the
`3. Windows SDK + Flutter Release Demo` job builds and validates
`MXLogger.Native.2.3.0.nupkg`. The package is a local-feed artifact;
it is not automatically published to nuget.org.

1. Download the nupkg to a folder such as `D:\NuGetFeed`, without extracting it.
2. Add that folder under Visual Studio **Tools → NuGet Package Manager → Package Manager Settings → Package Sources**.
3. Select x64 in the C++ project and install `MXLogger.Native` 2.3.0 from that source.

Alternatively, use the Visual Studio Package Manager Console:

```powershell
Install-Package MXLogger.Native -Version 2.3.0 -Source D:\NuGetFeed
```

NuGet imports the native `.targets`, include directories and matching static
library automatically. Native C++ static-library consumers do not need to
copy a `.lib` manually or distribute an MXLogger DLL.

```cpp
#include <mxlogger.hpp>
#include <mxlogger_util.hpp>

const char* version = mx_logger::version(); // "2.3.0"
auto* logger = mx_logger::initialize_namespace(
    "my.app", "C:/MyApp/Logs", "yyyy_MM_dd", "app", nullptr, nullptr, nullptr);
if (logger) {
    logger->log(1, "App", "Hello from Windows", "demo", true);
    mx_logger::destroy();
}
```

Use a directory writable by your application. Use Visual Studio 2022/v143 or a
compatible newer toolchain; the consuming MSVC tool version must not be older
than the version used to build the package.

| Project runtime | Debug | Release |
|---|---|---|
| Dynamic CRT (default) | `/MDd` | `/MD` |
| Static CRT | `/MTd` | `/MT` |

The package includes both configurations and both CRT families. It selects
Debug/Release using `UseDebugLibraries`, falling back to the configuration name
`Debug` when that property is absent. MD is the default. For an MT project, add:

```xml
<PropertyGroup>
  <MXLoggerRuntimeLibrary>MT</MXLoggerRuntimeLibrary>
</PropertyGroup>
```

Also set the project's **C/C++ → Code Generation → Runtime Library** to `/MTd`
or `/MT`. The SDK validates CRT compatibility instead of overriding your setting.
Custom configurations can set `MXLoggerUseDebugLibraries` to `true` or `false`.
Unset, `Default` and C++14 language settings are raised to C++17 before compilation,
including per-file settings; C++20 and later settings are preserved. Packaging
CI checks these rules and builds real consumer projects.

## Build the NuGet package locally

On Windows, install VS 2022 Desktop development with C++ (v143), CMake,
PowerShell 7, Python and the NuGet CLI, then run from the repository root:

```powershell
pwsh -File scripts/build_windows_nuget.ps1
```

Output: `build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg`.
Local logs: `build/windows-sdk/logs/`. The script tests Core and installed CMake
SDK consumers in MD/MT × Debug/Release, builds the FFI DLLs, packs the nupkg,
then restores it from the local feed. Standalone `.vcxproj` consumers verify
version queries, encrypted writes, decoding and rejection of incompatible CRT
settings. The script does not publish the package.

## Precompiled DLLs for Flutter

The nupkg contains `build/native/ffi/x64/{Debug,Release}/mxlogger_ffi.dll`,
`manifest.json` (Core/ABI version, architecture, hashes and source provenance),
and `build/native/include/mxlogger_ffi.h`. The DLL uses a static CRT. Strings and
arrays allocated by the DLL must use its paired free functions, not the caller's
`free`. The native C++ static-library integration does not automatically link or
copy this FFI DLL.

A local Windows computer is not required to produce the DLLs: Windows CI builds
and tests them through real Dart FFI. On macOS or Windows, download the nupkg
and run from the repository root:

```bash
python3 scripts/prepare_flutter_windows.py --package /path/to/MXLogger.Native.2.3.0.nupkg
python3 scripts/prepare_flutter_windows.py --check
```

This prepares `platform/flutter_mxlogger/windows/bin/x64/`. Flutter CMake only
validates and copies the binaries. Commit both DLLs and the manifest together,
and include them before publishing to pub; `.pubignore` keeps them in the package.
Flutter Windows consumers do not need NuGet or Core sources. Alternatively,
download the prepared `flutter_mxlogger-windows-prebuilt` CI artifact. After Core
changes, build and import a new package rather than retaining an older DLL.

## Flutter Windows Release Demo

After all platform API tests pass, CI produces
`MXLoggerFlutterDemo-windows-x64-Release`. Extract the entire artifact and run
`MXLoggerFlutterDemo.exe`. Keep the DLLs, VC++ runtime and `data/` beside the EXE.
This is the interactive `example/lib/main.dart` Demo. CI verifies its first
visible frame and retains separate FFI smoke checks. Test output appears in
GitHub Actions steps; separate Logs artifacts are not uploaded.

## Install through vcpkg

The repository provides a local **overlay port**, which builds the adjacent
Core sources. It has not been submitted to the public vcpkg registry. Keep the
complete checkout, not only the port directory. From a directory without a
`vcpkg.json`, use classic mode:

```powershell
vcpkg install mxlogger:x64-windows --overlay-ports=D:/src/MXLogger/platform/Windows/vcpkg/ports --no-binarycaching
```

For a static CRT, use `mxlogger:x64-windows-static`. Both triplets build a static
MXLogger library, using the MD and MT CRT families respectively. In manifest
mode, add the dependency to `vcpkg.json`:

```json
{ "dependencies": ["mxlogger"] }
```

Set the overlay path in `vcpkg-configuration.json`:

```json
{ "overlay-ports": ["../MXLogger/platform/Windows/vcpkg/ports"] }
```

CMake consumers use the same public target:

```cmake
find_package(MXLoggerCore 2.3 CONFIG REQUIRED)
target_link_libraries(MyApp PRIVATE MXLogger::Core)
```

Configure with the vcpkg toolchain and a triplet matching the project CRT.
For MT projects, also set `CMAKE_MSVC_RUNTIME_LIBRARY` to
`MultiThreaded$<$<CONFIG:Debug>:Debug>` and use CMake 3.20+.
When testing local changes with the same version, disable binary caching and
remove/reinstall mxlogger to avoid old artifacts. CI checks both triplets using
isolated install directories and no binary cache:

```powershell
pwsh -File scripts/verify_windows_vcpkg.ps1 -VcpkgRoot C:/vcpkg
```

## Standalone CMake SDK and versioning

To install Core without a package manager:

```powershell
cmake -S Core -B build/core-sdk -A x64 -DMXLOGGER_INSTALL=ON
cmake --build build/core-sdk --config Debug --parallel
cmake --install build/core-sdk --config Debug --prefix D:/MXLoggerSDK
cmake --build build/core-sdk --config Release --parallel
cmake --install build/core-sdk --config Release --prefix D:/MXLoggerSDK
```

Set `CMAKE_PREFIX_PATH=D:/MXLoggerSDK` in the consuming project and use
`find_package(MXLoggerCore CONFIG REQUIRED)`. Debug/Release libraries are
`MXLoggerCored.lib` / `MXLoggerCore.lib`; CMake selects the configuration.
Embedding the Core sources remains supported.

`Core/mxlogger_version.hpp` is the version source for the Core API, CMake and
NuGet. Also update the overlay's `vcpkg.json` when bumping the version; the port
rejects mismatches. For a future nuget.org release, first pass real Windows CI
and confirm ownership of the package ID, then publish with your own API key:

```powershell
nuget push build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg -Source https://api.nuget.org/v3/index.json -ApiKey $env:NUGET_API_KEY
```

See the [NuGet native-package guide](https://learn.microsoft.com/en-us/nuget/guides/native-packages)
and [vcpkg overlay documentation](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports).
