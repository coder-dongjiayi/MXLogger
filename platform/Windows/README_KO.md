# MXLogger Windows C++ SDK

[English](./README.md) | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | 한국어

**Windows 10/11 x64**용 네이티브 **C++17** SDK이며 Core 버전은 **2.3.0**입니다.
NuGet 패키지 ID는 `MXLogger.Native`, vcpkg port 이름은 `mxlogger`입니다.
두 방식 모두 같은 Core를 사용합니다. NuGet에는 Flutter/Dart용 C ABI DLL도 포함되며 .NET 래퍼는 제공하지 않습니다.

## 앱별 고유 네임스페이스 지정

**`com.company.product`처럼 앱별로 고정된 역도메인 형식의 네임스페이스를 사용하세요.**
예제를 자신의 도메인과 제품 이름으로 바꾸고, 서로 다른 앱에는 다른 네임스페이스를 지정해야 합니다.
네이티브 C++의 `ns` 인자와 Flutter의 `nameSpace` 인자에 해당하며, Bundle ID나 Windows 패키지 ID를 자동으로 읽는 값은 아닙니다.

Flutter Windows의 기본 로그 경로는
`%LOCALAPPDATA%/MXLogger/<확장자를 제외한 EXE 이름>/<nameSpace>/`입니다.
**EXE 이름만으로는 고유성을 보장할 수 없습니다.** 같은 Windows 사용자에서 EXE 이름과 네임스페이스가 모두 같으면 같은 디렉터리를 사용합니다.
네이티브 C++ 또는 Flutter에서 `directory`를 지정하면 Core는 `directory/nameSpace/`를 사용하므로 기본 디렉터리도 앱별로 지정하세요.
여러 프로세스가 의도적으로 로그를 공유할 때는 같은 디렉터리, 네임스페이스와 암호화 설정을 사용합니다.
EXE 이름을 바꿔도 경로를 유지하려면 `directory`를 명시적으로 지정하세요.

## 로컬 NuGet 피드에서 설치

`verify-logger`를 수동 실행하세요. 모든 플랫폼 API 테스트가 통과하면
`3. Windows SDK + Flutter Release Demo` 작업에서 `MXLogger.Native.2.3.0.nupkg`를 빌드하고 검증합니다.
이 파일을 로컬 피드에서 사용합니다. nuget.org에 자동 배포하지 않습니다.

1. nupkg를 `D:\NuGetFeed` 같은 폴더에 내려받습니다. 압축을 풀 필요는 없습니다.
2. Visual Studio의 **Tools → NuGet Package Manager → Package Manager Settings → Package Sources**에 해당 폴더를 추가합니다.
3. C++ 프로젝트에서 x64를 선택하고 이 소스로부터 `MXLogger.Native` 2.3.0을 설치합니다.

Package Manager Console에서도 설치할 수 있습니다.

```powershell
Install-Package MXLogger.Native -Version 2.3.0 -Source D:\NuGetFeed
```

NuGet이 네이티브 `.targets`, 공개 헤더 경로와 맞는 정적 라이브러리를 자동으로 설정합니다.
네이티브 C++ 정적 링크에서는 `.lib`를 직접 복사하거나 MXLogger DLL을 배포할 필요가 없습니다.

```cpp
#include <mxlogger.hpp>
#include <mxlogger_util.hpp>

const char* version = mx_logger::version(); // "2.3.0"
auto* logger = mx_logger::initialize_namespace(
    "com.company.product", "C:/MyApp/Logs", "yyyy_MM_dd", "app", nullptr, nullptr, nullptr);
if (logger) {
    logger->log(1, "App", "Hello from Windows", "demo", true);
    mx_logger::destroy();
}
```

앱에서 쓰기 가능한 로그 경로로 변경하세요. Visual Studio 2022/v143 또는 호환되는 최신 도구 체인을 사용하며,
사용하는 MSVC 버전은 패키지를 빌드한 버전보다 오래되지 않아야 합니다.

| 프로젝트 런타임 | Debug | Release |
|---|---|---|
| 동적 CRT(기본값) | `/MDd` | `/MD` |
| 정적 CRT | `/MTd` | `/MT` |

두 구성과 두 CRT 계열을 같은 패키지에 포함합니다. `UseDebugLibraries`로 Debug/Release를 선택하고,
설정이 없으면 구성 이름 `Debug`를 기준으로 판단합니다. 기본값은 MD 계열입니다. MT 프로젝트는 `.vcxproj`에 추가합니다.

```xml
<PropertyGroup>
  <MXLoggerRuntimeLibrary>MT</MXLoggerRuntimeLibrary>
</PropertyGroup>
```

프로젝트의 **C/C++ → Code Generation → Runtime Library**도 `/MTd` 또는 `/MT`로 설정하세요.
SDK는 기존 설정을 덮어쓰지 않고 불일치를 오류로 처리합니다. 사용자 지정 구성은 `MXLoggerUseDebugLibraries`를 `true` / `false`로 설정할 수 있습니다.
언어 설정이 없거나 `Default`, C++14이면 파일별 설정을 포함해 C++17로 올립니다. C++20 이상은 유지합니다.
패키징 CI는 이 규칙과 실제 사용 프로젝트 빌드를 검증합니다.

## 로컬 NuGet 패키지 빌드

Windows에 VS 2022 Desktop development with C++(v143), CMake, PowerShell 7, Python, NuGet CLI를 설치하고 저장소 루트에서 실행하세요.

```powershell
pwsh -File scripts/build_windows_nuget.ps1
```

결과는 `build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg`, 로컬 로그는 `build/windows-sdk/logs/`에 저장됩니다.
스크립트는 MD/MT × Debug/Release의 Core와 설치된 CMake SDK를 테스트하고 FFI DLL과 nupkg를 생성합니다.
그다음 로컬 피드에서 복원한 패키지를 별도의 `.vcxproj`에서 사용해 버전 조회, 암호화 기록, 복호화, CRT 불일치 거부를 검증합니다. 패키지를 배포하지는 않습니다.

## Flutter용 사전 빌드 DLL

nupkg에는 `build/native/ffi/x64/{Debug,Release}/mxlogger_ffi.dll`, `manifest.json`,
`build/native/include/mxlogger_ffi.h`가 포함됩니다. manifest에는 Core/ABI 버전, 아키텍처, 해시와 소스 출처를 기록합니다.
DLL은 정적 CRT를 사용합니다. DLL이 할당한 문자열과 배열은 같은 DLL의 대응 해제 함수를 호출해야 하며 호출자의 `free`로 해제하면 안 됩니다.
네이티브 C++ 정적 라이브러리 사용 시 FFI DLL을 자동으로 링크하거나 복사하지 않습니다.

Windows 컴퓨터가 없어도 Windows CI에서 DLL을 빌드하고 실제 Dart FFI 테스트를 수행할 수 있습니다.
nupkg를 내려받은 뒤 macOS 또는 Windows의 저장소 루트에서 실행하세요.

```bash
python3 scripts/prepare_flutter_windows.py --package /path/to/MXLogger.Native.2.3.0.nupkg
python3 scripts/prepare_flutter_windows.py --check
```

출력 경로는 `platform/flutter_mxlogger/windows/bin/x64/`입니다. Flutter CMake는 바이너리를 검증하고 복사하기만 합니다.
두 DLL과 manifest를 함께 커밋하고 pub 배포 전에 포함하세요. `.pubignore`가 이 파일들을 배포 패키지에 유지합니다.
Flutter Windows 사용자에게 NuGet이나 Core 소스는 필요하지 않습니다. 준비된 `flutter_mxlogger-windows-prebuilt` CI 결과물을 사용할 수도 있습니다.
Core를 변경하면 새 패키지를 빌드하고 가져와야 하며 이전 DLL을 그대로 사용하면 안 됩니다.

## Flutter Windows Release 데모

모든 플랫폼 API 테스트가 통과하면 CI가 `MXLoggerFlutterDemo-windows-x64-Release`를 생성합니다.
전체를 압축 해제한 뒤 `MXLoggerFlutterDemo.exe`를 실행하세요. DLL, VC++ 런타임과 `data/`를 EXE 옆에 유지해야 합니다.
이 결과물은 `example/lib/main.dart`의 실제 데모입니다. CI는 첫 화면 표시와 별도의 FFI 스모크 테스트를 검증합니다.
테스트 출력은 GitHub Actions의 각 단계에서 확인하며 별도의 로그 결과물은 업로드하지 않습니다.

## vcpkg로 설치

저장소의 **overlay port**는 인접한 Core 소스를 빌드합니다. 공개 vcpkg registry에는 제출하지 않았습니다.
port 디렉터리만 복사하지 말고 전체 checkout을 유지하세요. `vcpkg.json`이 없는 디렉터리에서 classic 모드로 실행합니다.

```powershell
vcpkg install mxlogger:x64-windows --overlay-ports=D:/src/MXLogger/platform/Windows/vcpkg/ports --no-binarycaching
```

정적 CRT 프로젝트는 `mxlogger:x64-windows-static`을 사용하세요. 두 triplet 모두 정적 MXLogger 라이브러리를 생성하며 CRT는 각각 MD / MT 계열입니다.
manifest 모드에서는 `vcpkg.json`에 의존성을 추가합니다.

```json
{ "dependencies": ["mxlogger"] }
```

`vcpkg-configuration.json`에 overlay 경로를 지정합니다.

```json
{ "overlay-ports": ["../MXLogger/platform/Windows/vcpkg/ports"] }
```

CMake는 같은 공개 target을 사용합니다.

```cmake
find_package(MXLoggerCore 2.3 CONFIG REQUIRED)
target_link_libraries(MyApp PRIVATE MXLogger::Core)
```

vcpkg toolchain과 프로젝트 CRT에 맞는 triplet을 지정하세요. MT 프로젝트는 CMake 3.20 이상을 사용하고
`CMAKE_MSVC_RUNTIME_LIBRARY`를 `MultiThreaded$<$<CONFIG:Debug>:Debug>`로 명시적으로 설정해야 합니다.
같은 버전의 로컬 변경을 검증할 때는 바이너리 캐시를 끄고 기존 mxlogger를 제거한 뒤 재설치하세요.
CI는 독립된 설치 경로와 비활성화된 캐시로 두 triplet을 검증합니다.

```powershell
pwsh -File scripts/verify_windows_vcpkg.ps1 -VcpkgRoot C:/vcpkg
```

## 독립 CMake SDK와 버전 관리

패키지 관리자 없이 Core를 설치할 수도 있습니다.

```powershell
cmake -S Core -B build/core-sdk -A x64 -DMXLOGGER_INSTALL=ON
cmake --build build/core-sdk --config Debug --parallel
cmake --install build/core-sdk --config Debug --prefix D:/MXLoggerSDK
cmake --build build/core-sdk --config Release --parallel
cmake --install build/core-sdk --config Release --prefix D:/MXLoggerSDK
```

사용 프로젝트에 `CMAKE_PREFIX_PATH=D:/MXLoggerSDK`를 설정하고 `find_package(MXLoggerCore CONFIG REQUIRED)`를 호출하세요.
Debug는 `MXLoggerCored.lib`, Release는 `MXLoggerCore.lib`이며 CMake가 선택합니다. Core 소스를 직접 포함하는 방식도 지원합니다.

`Core/mxlogger_version.hpp`가 Core API, CMake, NuGet의 버전 원본입니다.
버전을 올릴 때 overlay의 `vcpkg.json`도 갱신하세요. 불일치하면 port가 빌드를 거부합니다.
나중에 nuget.org에 배포하려면 실제 Windows CI와 패키지 ID 소유권을 확인한 뒤 자신의 API Key로 실행하세요.

```powershell
nuget push build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg -Source https://api.nuget.org/v3/index.json -ApiKey $env:NUGET_API_KEY
```

[NuGet 네이티브 패키지 안내](https://learn.microsoft.com/en-us/nuget/guides/native-packages)와
[vcpkg overlay 문서](https://learn.microsoft.com/en-us/vcpkg/concepts/overlay-ports)를 참고하세요.
