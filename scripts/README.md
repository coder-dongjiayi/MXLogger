# scripts 目录使用说明

本目录集中放置 MXLogger 的构建、打包、发布、源码同步和跨平台验证脚本。本文按当前实现整理常用入口和 `tests/` 下的测试文件。

## 运行约定

本文命令默认在仓库根目录 `MXLogger/` 执行。

| 文件类型 | 运行方式 | 基本要求 |
| --- | --- | --- |
| `.sh` | `bash scripts/文件名.sh` | Bash；部分脚本使用 Bash 特性，不要改用 `sh` |
| `.py` | `python3 scripts/文件名.py` | Python 3；Windows 可使用 `python` |
| `.ps1` | `pwsh -File scripts/文件名.ps1` | PowerShell 7；这些脚本用于 Windows 原生构建和验证 |

`ohos_release.sh` 使用 POSIX shell，可按 `sh scripts/ohos_release.sh 2.3.0` 调用。

实际依赖取决于脚本：Apple 构建需要 macOS、Xcode，涉及 Pods 时还需要 CocoaPods；Android 构建需要相应的 JDK、SDK、NDK；Windows 构建需要 Visual Studio C++ 工具链、CMake，打包时还需要 `nuget.exe`；HarmonyOS 构建需要 Python 3、DevEco Studio 及其 SDK，设备验证还需要 HDC 可访问的真机或模拟器。

先分清以下工程，避免运行错入口：

| 工程 | 用途 |
| --- | --- |
| `mxlogger_analyzer/` | 日志解析器的桌面和普通 Web 应用 |
| `platform/flutter_mxlogger/example/` | Flutter 日志 SDK 的演示应用，能够写入日志、修改配置、查看文件等 |
| `platform/macOS/MXLoggerDemo/`、`platform/Windows/MXLoggerDemo/`、`platform/Android/MXLogger/mxloggerdemo/` | 各平台原生日志 SDK 的 Demo |
| `platform/OHOS/` | 鸿蒙原生 ArkTS SDK 和 `entry` Demo；用 DevEco Studio 打开，当前独立于 Flutter 插件 |

`build_macos_demo_dmg.sh` 打包的是原生 macOS Demo；`run_flutter_macos_demo.sh` 启动的是 Flutter SDK Demo。解析器本身的桌面打包入口在 [`mxlogger_analyzer/tool/build_desktop.dart`](../mxlogger_analyzer/tool/build_desktop.dart)。

## 一、日常开发该选哪个

| 想做的事 | 使用方式 |
| --- | --- |
| 运行 macOS 日志解析器 | 在 `mxlogger_analyzer/` 执行 `flutter run -d macos -t lib/main_desktop.dart` |
| 用当前仓库源码运行 Flutter macOS Demo | `bash scripts/run_flutter_macos_demo.sh` |
| 检查刚改过的 C++ Core | `python3 scripts/verify_core_ci.py --configuration Debug` |
| 检查 Core 的 CMake 安装包能否被其他工程使用 | `bash scripts/verify_core_package.sh` |
| 验证 Apple 原生层和 Flutter 插件 | `python3 scripts/verify_macos_support.py` |
| 生成 Chrome 扩展安装包 | `bash scripts/build_analyzer_chrome_extension.sh 1.0.0`，版本号按实际填写 |
| 准备普通 Web 解析器资源 | `bash scripts/prepare_analyzer_web.sh` |
| 发布 Flutter 日志 SDK | 先运行 `bash scripts/pub_flutter_mxlogger.sh --dry-run` |
| 生成鸿蒙 OHPM 发布包 | `sh scripts/ohos_release.sh 2.3.0`，仅构建和本地校验，不上传 |
| 验证鸿蒙 SDK 与独立 HAR 接入 | `python3 scripts/verify_ohos_sdk.py --device DEVICE_ID` |
| 发布可嵌入的解析器内核包 | 先运行 `bash scripts/pub_mxlogger_analyzer.sh --dry-run` |
| 给 Flutter 包准备 Windows DLL | 从 Windows 生成的 NuGet 包运行 `prepare_flutter_windows.py --package ...` |

普通 Web 的完整构建脚本目前存在旧文件名引用，见本文最后的“当前已知限制”。

## 二、构建和打包

### [prepare_analyzer_web.sh](prepare_analyzer_web.sh)

为普通 Web 解析器准备运行资源：

- 在 `mxlogger_analyzer/` 运行 `flutter pub get --offline`。
- 从 `chrome_extension/web/` 复制 JS 桥接代码、字体清单、SQLite WASM、样例日志等到 `mxlogger_analyzer/web/`。
- 把 `chrome_extension/lib/worker.dart` 编译成 `web/worker.js`，让解析、解密和查询在独立 Worker 中执行。

运行：`bash scripts/prepare_analyzer_web.sh`。首次使用前应先在 `mxlogger_analyzer/` 执行一次 `flutter pub get`，保证依赖已缓存。

它会生成或覆盖 Web 资源，不会生成最终发布目录。脚本直接调用 PATH 中的 `flutter` 和 `dart`。

### [build_analyzer_web.sh](build_analyzer_web.sh)

用于构建普通 Web 解析器的 Release 版本，入口是 `lib/main_web.dart`，目标输出是 `mxlogger_analyzer/build/web/`。

它先准备 Web 资源，再执行 `flutter build web`；启用 CSP、本地 Web 运行资源，并关闭 PWA Service Worker。传入的额外参数会转交 Flutter，例如 `--base-href /mxlogger/`。

**当前脚本仍调用不存在的 `prepare_web.sh`，不能直接完成构建。** 临时替代命令见本文最后一节。

### [build_analyzer_chrome_extension.sh](build_analyzer_chrome_extension.sh)

构建并打包 Chrome 扩展版解析器，必须传入扩展版本号：

```bash
bash scripts/build_analyzer_chrome_extension.sh 1.0.0
```

流程是验证版本号、离线获取 Flutter 依赖、构建扩展 Web 页面、编译 Worker，最后调用扩展工程的 `tool/package.py` 整理发布文件。

产物在 `mxlogger_analyzer/chrome_extension/dist/`：

- `mxlogger-chrome-prototype/`：可加载的未打包扩展。
- `mxlogger-chrome-prototype.zip`：扩展安装包。
- `package-size.json`：包体积报告。
- `font-packs/`：独立的可选字体包。

版本号由 1～4 段数字组成，每段在 0～65535 之间，不能有前导零，也不能全部为零。脚本只生成本地文件，不上传 Chrome 应用商店。首次运行前需在扩展工程完成依赖缓存。

### [build_macos_demo_dmg.sh](build_macos_demo_dmg.sh)

打包**原生 macOS Demo** 的通用 Release DMG：安装本地 Pods、检查 Core 来源、构建 arm64 和 x86_64、运行冒烟测试、验证签名，然后制作并校验 DMG。

运行：`bash scripts/build_macos_demo_dmg.sh`。

产物：`build/macos-native-demo/MXLoggerDemo-macOS-Release.dmg`，日志也在 `build/macos-native-demo/`。应用使用 ad-hoc 签名，没有 Apple 公证。CI 在各平台验证通过后才调用它；单独执行脚本不会自动跑完全部 CI。

### [build_windows_ffi.ps1](build_windows_ffi.ps1)

在 Windows 上编译 Dart FFI 使用的 x64 `mxlogger_ffi.dll`，同时生成 Debug、Release 两套 DLL 和带 SHA-256、Core 来源信息的 `manifest.json`。

```powershell
pwsh -File scripts/build_windows_ffi.ps1 -Destination build/windows-ffi/bin/x64
```

`-Destination` 必填；`-BuildDirectory` 可指定构建目录，默认 `build/windows-ffi/`；`-Toolset` 默认 `v143`。DLL 使用静态 CRT。本脚本不运行 Core 单元测试，也不生成 NuGet 包。

### [build_windows_nuget.ps1](build_windows_nuget.ps1)

构建 Windows 原生 SDK 的 NuGet 包，版本号读取自 `Core/mxlogger_version.hpp`。

默认会构建 MD、MT 两种 CRT 配置及各自的 Debug、Release 静态库，运行 Core 测试和安装后消费者测试，再加入 FFI DLL、公开头文件及 MSBuild targets。打包后还会从本地源还原实际 NuGet 包，验证编译、链接、读写、C++ 标准配置和 CRT 不兼容检查。

运行：`pwsh -File scripts/build_windows_nuget.ps1`。

- `-Toolset`：默认 `v143`。
- `-PackageOnly`：跳过 Core 测试和消费者验证，用于 CI 第二阶段的测试包；仍会编译、打包和检查源码来源。

产物：`build/windows-sdk/packages/MXLogger.Native.<版本>.nupkg`；日志在 `build/windows-sdk/logs/`。它不执行 NuGet 上传。

## 三、发布脚本

以下四个脚本调用真实的包仓库发布命令。Android 的脚本则只生成待上传的 ZIP，见后面的说明。

| 脚本 | 发布对象与行为 | 使用方式 |
| --- | --- | --- |
| [pub_flutter_mxlogger.sh](pub_flutter_mxlogger.sh) | 发布 `platform/flutter_mxlogger/` 中的 `flutter_mxlogger`；使用 `flutter_env.sh` 定位 SDK，固定发布到 pub.dev | `bash scripts/pub_flutter_mxlogger.sh --dry-run` 先预检；去掉 `--dry-run` 才发布 |
| [pub_mxlogger_analyzer.sh](pub_mxlogger_analyzer.sh) | 发布 `mxlogger_analyzer/mxlogger_analyzer_lib/` 中的解析器内核；桌面/Web 壳工程不发布到 pub.dev | `bash scripts/pub_mxlogger_analyzer.sh --dry-run` 先预检；去掉 `--dry-run` 才发布 |
| [push_mxlogger_core.sh](push_mxlogger_core.sh) | 调用 `pod trunk push` 发布根目录的 `MXLoggerCore.podspec` | `bash scripts/push_mxlogger_core.sh` |
| [push_mxlogger.sh](push_mxlogger.sh) | 清理本机 MXLogger Pod 缓存后，调用 `pod trunk push` 发布 `MXLogger.podspec` | `bash scripts/push_mxlogger.sh` |

两个 `push_` 脚本发布的是 CocoaPods 包，**不是 Git push**；它们都会加载 `pod_validation_env.sh`。`MXLogger.podspec` 依赖对应版本的 `MXLoggerCore`，发布时先处理 Core。

Flutter 发布脚本只转交 `pub publish`，没有内置全部平台的构建、测试或 Windows DLL 准备流程。发布前应另外确认所需验证和产物准备已经完成。

### [android_release.sh](android_release.sh)

为 Android SDK 制作 Maven Central 待上传包：构建 AAR 和 Javadoc、打包 Java/Kotlin 源码、生成 POM、调用本机 GPG 签名并生成摘要，最后按 Maven 目录结构生成 ZIP。

```bash
bash scripts/android_release.sh 2.3.0
```

- 必须传入版本号，坐标固定为 `io.github.coder-dongjiayi:mxlogger`。
- macOS 未设置 `JAVA_HOME` 时会自动查找 JDK 17。
- 需要脚本中配置的 GPG 签名密钥，以及 Gradle、Android 构建环境和相关打包工具。
- `SKIP_BUILD=1` 可跳过 Gradle 构建，改用已有 AAR；此时会按文件修改时间检查源码是否更新。
- 会覆盖同版本输出 ZIP，并清理自己的 staging 和版本临时目录。

产物：`scripts/release/<版本>_mxlogger.zip`。脚本**不会自动上传 Maven Central**，也没有先运行全部测试。

### [ohos_release.sh](ohos_release.sh)

按传入的 SemVer 版本生成鸿蒙 Release HAR：

```sh
sh scripts/ohos_release.sh 2.3.0
```

通过 `build_ohos_har.py` 在隔离工程中编译 ARM64 / x86_64，写入包版本，检查作者、关键词、公开 API、
项目主页、`example/` 示例源码及说明、文档、许可证和 C ABI 导出，并运行 `ohpm prepublish`。不修改源码版本或签名配置，不自动发布。

默认使用 `/Applications/DevEco-Studio.app/Contents`，可通过 `DEVECO_HOME` 指定其他路径。
输出为 `build/ohos-release/<版本>/mxlogger-<版本>.har`，同目录包含摘要、报告和构建日志。
配置中心仓发布认证后，可手动执行 `ohpm publish build/ohos-release/2.3.0/mxlogger-2.3.0.har`。

## 四、源码同步、二进制准备与环境辅助

### [sync_flutter_native.py](sync_flutter_native.py)

把 Core 的两个 FFI 公共文件同步到 Flutter Apple 桥接层：

- `Core/ffi/mxlogger_ffi.h` → Apple 插件的 `include/flutter_mxlogger/`。
- `Core/ffi/mxlogger_ffi_memory.hpp` → Apple 插件源码目录。

`python3 scripts/sync_flutter_native.py` 会复制不同的文件；加 `--check` 只检查，不修改，文件缺失或内容不一致时失败。

修改 Core 的 FFI 声明或内存管理头后使用。它不复制整套 Core，也不构建 Windows DLL。

### [sync_spm_mirror.sh](sync_spm_mirror.sh)

将当前仓库的 Core 和 Objective-C 层整理成 SwiftPM 标准目录，并复制 `spm/Package.swift`、README 和许可证。

```bash
bash scripts/sync_spm_mirror.sh build/spm
```

可传入输出目录；不传时，优先使用相邻的 `../mxlogger-spm/`，不存在才使用 `build/spm/`。

脚本通过 `rsync --delete` 让输出内容与当前源码一致，会覆盖文件并删除输出目录中的多余分发文件；保留 `.git`、SwiftPM 缓存和指定的 IDE 配置。因此输出目录应专门用于镜像。它不会自动 commit、创建 tag 或 push，远程 SwiftPM 版本仍需另行发布。

### [prepare_flutter_windows.py](prepare_flutter_windows.py)

从本地 `MXLogger.Native` NuGet 包取出预编译 Windows DLL，放入 Flutter 插件的 `windows/bin/x64/`，让 Flutter 包消费者直接使用二进制。

```bash
python3 scripts/prepare_flutter_windows.py \
  --package build/windows-sdk/packages/MXLogger.Native.2.3.0.nupkg
python3 scripts/prepare_flutter_windows.py --check
```

- `--package`：读取本地 `.nupkg` 并准备 DLL，会替换目标 `windows/bin/x64/`。
- `--check`：只检查已准备的 DLL 和清单。
- `--plugin`：可指定其他 Flutter 插件目录，默认本仓库 `platform/flutter_mxlogger/`。

会检查包名、版本、FFI ABI、x64 PE DLL 格式及 SHA-256。当前实现固定接受 Core `2.3.0`、x64、FFI ABI 1。它不编译、不联网，也不需要 NuGet 客户端，macOS 上同样可运行。

### [flutter_env.sh](flutter_env.sh)

供其他脚本 `source` 的 Flutter 路径查找工具，定义 `mxlogger_resolve_flutter <工程目录>`，将结果写入 `FLUTTER_BIN`。

依次查找显式 `FLUTTER_BIN`、PATH 中的 Flutter、工程及祖先目录的 FVM 链接、`android/local.properties`，最后尝试 `FLUTTER_ROOT` 和 `~/fvm/default`。

它本身不会启动 Flutter。当前两个 `pub_` 脚本使用它；不能假定目录内的其他 Flutter 脚本都支持同样的自动查找。

### [pod_validation_env.sh](pod_validation_env.sh)

由两个 CocoaPods 发布脚本 `source`，参数是待验证的 podspec 路径。

它读取 podspec 和本机 Apple SDK 支持的最低系统版本，生成临时 xcconfig，并设置 `XCODE_XCCONFIG_FILE`，用于本机发布验证。已有显式 xcconfig 会被包含进来，临时目录在调用脚本退出时删除。

它调整的是验证工程的编译目标，不修改 podspec 对外声明的最低版本；也不会修改解析器工程的 Podfile。

## 五、Core 和 API 检查

| 脚本 | 检查内容 | 参数、输出 |
| --- | --- | --- |
| [verify_core_ci.py](verify_core_ci.py) | 编译并运行当前仓库 Core 的 C++ 单元测试，并验证 CMake 确实使用当前源码 | 必填 `--configuration Debug` 或 `Release`；输出 `build/core-ci/<配置>/`，包括日志、`local-core.json`、JUnit `test-results.xml` |
| [verify_core_package.sh](verify_core_package.sh) | 构建、测试并安装 Debug/Release C++ SDK，再移动安装目录，让独立消费者编译和读写，验证安装包可迁移 | 可选 `--skip-core-tests`，仍运行消费者测试；需要 Ninja Multi-Config；输出 `build/core-package/run-*/` |
| [check_local_core.py](check_local_core.py) | 检查实际使用的是当前 checkout 的 Core，避免测试意外链接已发布的旧包 | 接受可重复的 `--cmake-cache`、`--pod-lock`、`--spm-mirror`、`--xcode-project`，至少一种；必填 `--output`，输出含版本、源码 SHA-256 和依赖证据的 JSON |
| [check_api_coverage.py](check_api_coverage.py) | 汇总 C++、Apple、Java、Dart 的公开 API 执行证据，发现未覆盖 API 时失败 | 必填 `--core-json`、`--apple-json`、`--apple-log`、`--java-xml`、`--dart-lcov`、`--output`；输出 JSON 和同名 HTML |

`check_local_core.py` 的不同输入分别检查 CMake 源码路径、Pods 本地依赖路径、SwiftPM 镜像中的 Core 文件内容，以及 Xcode 的 Core 子工程引用。它验证依赖来源，本身不运行 API 测试。

`check_api_coverage.py` 需要先生成 LLVM coverage JSON、XCTest 日志、JaCoCo XML 和 Dart LCOV。它只读取并汇总这些证据，不负责先跑测试；检查的是公开 API 入口是否执行或有明确断言，不代表所有代码行、分支、异常路径都达到 100% 覆盖。当前 `verify-logger.yml` 没有调用这个汇总脚本。

常用命令：

```bash
python3 scripts/verify_core_ci.py --configuration Debug
python3 scripts/verify_core_ci.py --configuration Release
bash scripts/verify_core_package.sh

# 检查上一步的 CMake 构建是否来自当前仓库
python3 scripts/check_local_core.py \
  --cmake-cache build/core-ci/Debug/CMakeCache.txt \
  --output build/core-ci/Debug/manual-local-core.json
```

## 六、原生平台与 Demo 验证

| 脚本 | 用途 | 参数、前置条件与产物 |
| --- | --- | --- |
| [verify_android_native.sh](verify_android_native.sh) | 不经过 Gradle，用 CMake/NDK 编译 Core、JNI 和 Flutter 桥接代码，覆盖 arm64-v8a、armeabi-v7a、x86_64、x86；检查没有错误引入 `flock` 依赖 | 需要 `ANDROID_NDK_HOME` 或 `ANDROID_NDK_ROOT`、CMake、Ninja；固定 Android API 21、Release；日志在 `build/android-validation/`，不运行设备测试 |
| [verify_android_api_host.sh](verify_android_api_host.sh) | 在宿主机编译真实 JNI/Core，运行 Java API 测试和 JaCoCo 报告；Android Context/Looper 由 mockable android.jar 提供 | 可选 `--skip-core-tests`；需要 JDK/Gradle 环境；日志在 `build/android-api-host/`，覆盖率报告在 Android 库的 `build/reports/jacoco/apiCoverageReport/` |
| [verify_android_device.sh](verify_android_device.sh) | 执行真正的 Android instrumentation 测试，并检查 XML 结果中没有失败、错误、跳过且测试数不为零 | 需要已连接的 Android 设备或模拟器和 Android 构建环境；日志在 `build/android-device-tests/tests.log` |
| [verify_android_demo.sh](verify_android_demo.sh) | 默认运行 Android 库和 Demo 的 Release JVM 测试；`package` 模式构建 Demo APK，校验签名、四种 ABI 和 Core 来源 | 参数 `test` 或 `package`，默认 `test`；SDK 环境涉及 Android 31/33 和 Build Tools 34.0.0；日志在 `build/android-demo/` |
| [verify_ios_api.sh](verify_ios_api.sh) | 自动选择可用 iOS runtime，创建临时 iPhone 模拟器，运行原生 XCTest、生命周期测试及代码覆盖率，并检查测试无跳过 | 需要 Xcode 和兼容的 iOS 模拟器 runtime；结束时关闭并删除临时模拟器；输出 `build/ios-api-tests/run-*/`，包括 `Tests.xcresult`、日志和摘要 |
| [verify_macos_demo.sh](verify_macos_demo.sh) | 安装本地 Pods，构建原生 macOS Demo 的 Debug/Release，运行功能冒烟和 UI 冒烟检查 | 需要 macOS、Xcode、CocoaPods；日志和 UI 预览在 `build/macos-native-demo/`，不生成 DMG |
| [verify_ohos_poc.py](verify_ohos_poc.py) | 最小调用链和明文 / AES 重启读取验证 | `--host`、`--native`、`--device DEVICE_ID`；真机需要签名 debug HAP；输出 `build/ohos-poc/` |
| [verify_ohos_sdk.py](verify_ohos_sdk.py) | 构建 Release HAR、独立消费工程，并可运行真机 SDK / Worker 验收 | `--host` 运行主机 ASan；`--device DEVICE_ID` 运行设备验收；输出 `build/ohos-sdk/` |
| [verify_ohos_demo.py](verify_ohos_demo.py) | 对已安装原生 Demo 执行真实 UI 操作与状态检查 | `--device DEVICE_ID`；测试写入、配置、文件、生命周期和明文 / AES 初始化，输出 `build/ohos-sdk/demo-ui/` |
| [verify_windows_demo.ps1](verify_windows_demo.ps1) | 构建 Windows 原生 Demo，运行模型及窗口自测，并检查 PASS 报告和截图 | `-Configuration Debug` 或 `Release`，默认 Debug；输出 `build/windows-native-demo/<配置>/`，程序在其 `bin/<配置>/`，报告在 `self-test/` |
| [verify_windows_vcpkg.ps1](verify_windows_vcpkg.ps1) | 验证本地 vcpkg overlay，覆盖 x64-windows、x64-windows-static 两种 triplet 的 Debug/Release 消费者编译和读写 | `-VcpkgRoot` 默认取 `VCPKG_INSTALLATION_ROOT`；构建在 `build/windows-sdk/vcpkg/`，日志在 `build/windows-sdk/logs/`；会重新安装测试依赖并临时关闭二进制缓存 |

鸿蒙导出日志可用现有解析器复验：`verify_ohos_logs.dart` 检查重启日志报告；
`verify_ohos_benchmark.dart EXPORTED_DEMO_DIRECTORY --aes` 检查最近一轮十万条基准的内容、顺序及逐条大小。
两者需通过 `dart --packages=mxlogger_analyzer/mxlogger_analyzer_lib/.dart_tool/package_config.json scripts/<脚本名>` 运行。
完整命令和运行边界见[鸿蒙 SDK 文档](../platform/OHOS/README.md)。

Android Demo 打包命令与产物：

```bash
bash scripts/verify_android_demo.sh test
bash scripts/verify_android_demo.sh package
```

最终 APK 是 `build/android-demo/MXLoggerDemo-android-Release.apk`，使用测试签名。`package` 模式不会先自动执行 `test` 模式；在 CI 中由前置验证任务保证顺序。

## 七、Flutter 插件运行与集成验证

### [run_flutter_macos_demo.sh](run_flutter_macos_demo.sh)

使用当前仓库尚未发布的原生源码运行 Flutter SDK Demo，工作目录是 `platform/flutter_mxlogger/example/`。

```bash
bash scripts/run_flutter_macos_demo.sh                 # 默认 run
bash scripts/run_flutter_macos_demo.sh build --release
bash scripts/run_flutter_macos_demo.sh test
```

支持 `run`、`build`、`test`，后面的参数透传给相应 Flutter 命令；`test` 使用 `flutter drive` 运行 macOS Demo 集成测试。

可用 `FLUTTER_BIN=/path/to/flutter` 指定 SDK。脚本会先 `pub get`，并仅对当前进程设置 `FLUTTER_SWIFT_PACKAGE_MANAGER=false`、`MXLOGGER_LOCAL_NATIVE=1`，让 Demo 使用本地 CocoaPods 源码，不修改 Flutter 全局设置。

### [verify_macos_support.py](verify_macos_support.py)

Apple 和 Flutter 插件的完整本地回归入口。它在独立临时副本中验证本地 CocoaPods 和 SwiftPM 两条链路，不依赖对应原生版本已对外发布。

默认内容包括 Core 测试、安装后 SDK 消费者测试、Objective-C/Swift 测试、iOS 原生 Demo 构建、macOS 原生 Demo 检查，以及 Flutter 静态分析、单元测试、iOS 桥接编译、macOS API/Demo 集成测试、Release 运行和 FFI 导出符号检查。

```bash
python3 scripts/verify_macos_support.py --package-manager both
```

| 参数 | 含义 |
| --- | --- |
| `--flutter <路径>` | 指定 Flutter；该验证工具要求 Flutter 3.44+，不代表插件最低支持版本也升到了 3.44 |
| `--package-manager pods\|spm\|both` | 选择验证的依赖管理方式，默认 `both` |
| `--skip-native` | 跳过额外的原生测试阶段；Flutter 单元和集成验证仍会执行 |
| `--offline` | `pub get` 使用已缓存依赖；不是禁止所有联网操作，脚本仍会调用 Flutter precache |
| `--keep-builds` | 保留成功运行的 Flutter 测试副本，可能占用数 GB 空间 |
| `--ios-integration` | 另外在临时 iOS 模拟器中执行 Flutter 移动 API 集成测试；只在 Pods 路径执行，单选 `spm` 时不会运行这一项 |

需要 macOS、Xcode、CocoaPods 和 Flutter。日志、截图及 `summary.json` 在 `build/macos-validation/run-*/logs/`；默认成功后清理大型测试副本，失败时保留现场。

### [verify_flutter_android.py](verify_flutter_android.py)

复制 Flutter 插件到独立临时目录，设置本地原生源码路径，在 Android 设备上执行 `mobile_logger_test.dart`，再检查 Gradle/JNI/Core 依赖来源。

```bash
python3 scripts/verify_flutter_android.py --device emulator-5554
```

`--flutter` 可指定 SDK；`--device` 默认为 `emulator-5554`；`--build-only` 改为只构建 arm64 Debug 测试 APK，不安装、不执行设备测试，因此不能当作完整设备验证通过。

日志和依赖来源报告在 `build/flutter-android-tests/run-*/`。成功后删除复制的插件及其构建缓存，保留日志和来源报告。

### [verify_flutter_windows.ps1](verify_flutter_windows.ps1)

验证 Windows 预编译 DLL 的完整消费链路：检查共享 ABI 头、从本地 NuGet 源还原包、准备 DLL、核对 SHA-256 与当前 Core 来源、检查 C 导出符号、运行真实 Dart FFI 测试，并将插件复制到独立目录构建 Flutter 应用，再移动应用目录运行测试。

```powershell
pwsh -File scripts/verify_flutter_windows.ps1 -Configuration Debug
```

| 参数 | 含义 |
| --- | --- |
| `-Configuration Debug` / `Release` | 默认 Debug |
| `-PackagePath <nupkg>` | 使用已有本地包；不传会调用 `build_windows_nuget.ps1 -PackageOnly` 创建测试包 |
| `-SkipExample` | 跳过 Flutter 示例应用构建和运行；DLL 与 Dart FFI 测试仍执行 |
| `-DemoOutputDirectory <目录>` | 另存完整的交互式 Flutter Release Demo，含运行库和资源；必须选择 Release，且不能同时使用 `-SkipExample`；已有目标目录会被替换 |

日志、导出符号和运行报告在 `build/flutter-windows-tests/<配置>/`。它会更新仓库 Flutter 插件的 `windows/bin/x64/`。当前相关包名、版本及报告检查中多处固定为 `2.3.0`，升级版本时要同步维护。

## 八、tests 和 release 子目录

### [tests/test_flutter_windows_package.py](tests/test_flutter_windows_package.py)

测试 `prepare_flutter_windows.py` 和 Flutter Windows CMake 二进制选择规则，包括包名/版本、ABI、架构、哈希、缺失 DLL、路径隔离，以及 Debug/Release/Profile 的 DLL 选择。

```bash
python3 -m unittest discover -s scripts/tests -p 'test_flutter_windows_package.py' -v
```

这些测试使用模拟 PE 文件头，可以在非 Windows 系统运行；其中 CMake 测试需要安装 CMake，否则会跳过。它验证打包规则，真正加载 DLL 的验证由 `verify_flutter_windows.ps1` 完成。

### [release/](release/)

保存 `android_release.sh` 生成的 Android 发布 ZIP，目前有 `2.1.0_mxlogger.zip`、`2.2.0_mxlogger.zip`、`2.3.0_mxlogger.zip`。这些是待上传产物，不是脚本，也不表示已经上传到远程包仓库。

## 九、CI 中的调用关系

当前 [`.github/workflows/verify-logger.yml`](../.github/workflows/verify-logger.yml) 分为三阶段：

1. **Core 基础验证**：跨系统运行 `verify_core_ci.py`，检查共享 Flutter ABI 头，以及 Windows 打包规则测试。
2. **各平台 API 和 Demo 验证**：依赖第一阶段通过，运行 Windows、iOS、macOS、Android，以及 Flutter Apple/Android/Windows 的验证任务。
3. **分发产物构建**：依赖第二阶段各项通过，再生成 Windows NuGet、vcpkg 分发源码、原生/Flutter Demo、macOS DMG 和 Android APK，上传为 GitHub Actions artifacts。

CI 上传构建产物与 pub.dev、CocoaPods、Maven Central 等包仓库的正式发布是两套操作。单独执行一个构建或发布脚本，也不会自动触发上述完整验证链路。

## 十、当前已知限制

### 普通 Web 脚本的旧名称引用

当前真实文件名是 `prepare_analyzer_web.sh` 和 `build_analyzer_web.sh`，但后者内部仍调用 `prepare_web.sh`；这两个脚本的文件头注释和 `mxlogger_analyzer/README.md` 中也还保留了 `prepare_web.sh`、`build_web.sh` 的旧名称。

在修正脚本前，可以从仓库根目录使用以下等价步骤：

```bash
# 首次运行或本机缺少依赖缓存时执行
(cd mxlogger_analyzer && flutter pub get)

bash scripts/prepare_analyzer_web.sh
(
  cd mxlogger_analyzer
  flutter build web --release --no-pub --csp --no-web-resources-cdn \
    --pwa-strategy=none -t lib/main_web.dart
)
```

部署到子路径时，在 `flutter build web` 后追加 `--base-href /mxlogger/`。这组命令根据脚本当前实现整理；本文编写过程没有实际执行构建或发布。

### 版本和平台选择

- 部分 Windows 准备/验证脚本固定原生版本 `2.3.0`，并非全部从版本头动态读取。Flutter 包版本与原生 Core 版本也应分别核对。
- `sync_spm_mirror.sh` 只同步本地源码，不发布远程 tag；需要远程 SwiftPM 版本时，还必须完成镜像仓库的 commit、tag 和 push。
- 大部分验证工具会实际编译、启动应用或模拟器，并生成构建缓存；`--check`、`--dry-run`、`--build-only`、`-PackageOnly` 的含义不同，不能互相替代。
