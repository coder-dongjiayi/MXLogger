<p align="center">
  <img src="https://img.shields.io/badge/iOS-9.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/macOS-10.13+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Android-minSdk%2021-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Flutter-3.7+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/%E8%A7%A3%E6%9E%90%E5%99%A8-macOS%20%7C%20Windows%20%7C%20Linux-6C5CE7?style=for-the-badge&logo=flutter&logoColor=white" alt="解析器桌面端" />
  <a href="https://chromewebstore.google.com/detail/mxlogger-analyzer/bpjhmakllccpeiglbfngmdbelimlghfi"><img src="https://img.shields.io/badge/Chrome-Install%20extension-4285F4?style=for-the-badge&logo=googlechrome&logoColor=white" alt="从 Chrome 应用商店安装 MXLogger Analyzer" /></a>
  <a href="https://pub.dev/packages/mxlogger_analyzer_lib"><img src="https://img.shields.io/pub/v/mxlogger_analyzer_lib?style=for-the-badge&label=analyzer%20lib&logo=dart" alt="pub analyzer" /></a>
</p>

<p align="center">
  <a href="https://github.com/coder-dongjiayi/MXLogger/blob/main/LICENSE.TXT"><img src="https://img.shields.io/badge/license-BSD--3-brightgreen.svg?style=flat-square" alt="license" /></a>
  <a href="https://cocoapods.org/pods/MXLogger"><img src="https://img.shields.io/cocoapods/v/MXLogger?style=flat-square&label=pod" alt="CocoaPods" /></a>
  <a href="https://central.sonatype.com/artifact/io.github.coder-dongjiayi/mxlogger"><img src="https://img.shields.io/maven-central/v/io.github.coder-dongjiayi/mxlogger?style=flat-square&label=maven%20central" alt="Maven Central" /></a>
  <a href="https://pub.dev/packages/flutter_mxlogger"><img src="https://img.shields.io/pub/v/flutter_mxlogger?style=flat-square&label=pub&logo=dart" alt="pub" /></a>
</p>

[English](./README.md) | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md)

<p align="center" >
<img src="./platform/flutter_mxlogger/example/assets/mxlogger_logo.png" alt="MXLogger"  title="MXLogger" width="180" />
</p>

MXLogger 是基于 **mmap** 内存映射机制的跨平台日志库，支持 **AES-CFB-128** 加密，支持 iOS / macOS / Android /
Flutter。核心代码使用 C/C++ 实现，序列化使用 Google 开源的 **FlatBuffers**，Flutter 端通过 `dart:ffi`
直接调用，性能几乎与原生一致。iPhone 11 上写入 10 万条（每条约 134 字节）耗时约 **0.13s**。

配套提供 **mxlogger_analyzer** 日志解析器：导入、解密、检索产出的 `.mx` 二进制日志，支持 Chrome 扩展、
桌面 app（macOS/Windows/Linux），也能以悬浮球的形式直接嵌进你的 iOS/Android Flutter app 里看端上日志。

- [日志解析器](#日志解析器)
- [安装引入](#安装引入)
- [快速开始](#快速开始)
- [API 一览](#api-一览)
  - [iOS](#ios-api) · [Android](#android-api) · [Flutter](#flutter-api) · [解析器](#analyzer-api)
- [存储策略与日志等级](#存储策略与日志等级)
- [性能测试](#性能测试)
- [注意事项](#注意事项)

## 整体结构

<img src="./icon/jiegoutu.webp" alt="结构图" width="640" />

MXLogger 主要解决日志**写入**和日志**分析**两件事。至于日志上报时机应该由业务决定：MXLogger 已经把日志目录
（`diskCachePath`）暴露出来，由开发调用原生平台的文件上传代码传到自己的服务器，下载后再用
mxlogger_analyzer 解析。

---

# 日志解析器

`.mx` 是二进制文件（AES-CFB-128 + flatbuffer），必须用解析器打开。解析器把记录写入 sqlite，基于它提供
全文检索、等级/时间/Tag/Name 过滤和 JSON 语法树查看。

| 形态 | 说明 | 获取方式 |
| --- | --- | --- |
| Chrome 扩展 | 在 Chrome 浏览器中解析 `.mx` 日志 | [从 Chrome 应用商店安装](https://chromewebstore.google.com/detail/mxlogger-analyzer/bpjhmakllccpeiglbfngmdbelimlghfi) |
| 桌面 app | macOS/Windows/Linux 客户端，拖入或选择日志文件即可分析 | [Releases](https://github.com/coder-dongjiayi/MXLogger/releases)（CI 三端出包） |
| 嵌入宿主 app | iOS/Android Flutter app 内的悬浮球 + 底部弹窗 | pub.dev 依赖 `mxlogger_analyzer_lib` |

安装 Chrome 扩展：在 Chrome 中打开上方商店链接，点击「添加至 Chrome」→「添加扩展程序」。
安装后从扩展菜单打开 **MXLogger Analyzer**，选择或拖入 `.mx` 文件，按需填写解密 KEY/IV，然后开始导入。

**数据页**：等级分布条 + 等级 chips、搜索与时间过滤、日志卡片内的 JSON 语法着色树、
`@name` / `#tag` 点击即过滤、单条信息 / 分享 / 全屏 / 复制。右上角可切换深浅主题。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_dark.png" alt="解析器数据页" width="900" />

**首次使用三步向导**：① 拖入或选择 `.mx` 文件 → ② 配置解密 KEY/IV（可添加多组，勾选框里的序号就是解密
尝试顺序）→ ③ 真实进度导入。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_wizard.png" alt="首次引导向导" width="900" />

**单条日志全屏详情**（Esc 关闭）：Name / Tags / 时间 / 等级 + 完整 JSON 树，可整条分享或复制。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_detail.png" alt="日志全屏详情" width="900" />

**嵌入宿主 app**（手机）：占屏 85% 的底部弹窗——留白收窄、文案让位于图标、等级 chips 横向滚动、
日志卡片默认折叠、四个操作收进「⋯」菜单。

<p align="center">
<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/mobile_embed.png" alt="嵌入式底部弹窗" width="340" />
</p>

解析器完整文档见 [mxlogger_analyzer_lib/README.zh-CN.md](./mxlogger_analyzer/mxlogger_analyzer_lib/README.zh-CN.md)。

---

# 安装引入

各平台封装与示例统一位于 `platform/`：`Windows/`、`macOS/`、`iOS/`、`Android/` 和 `flutter_mxlogger/`。
共享引擎 `Core/`、`scripts/`、`spm/` 及 CocoaPods 规格文件仍位于仓库根目录。
已有工程迁移后，请从新路径重新打开 IDE；备份并重新生成相关 CMake 构建目录，再执行 `flutter pub get` / `pod install` 更新本地依赖路径。

## iOS

```ruby
pod 'MXLogger', '~> 2.3.0'
```

## 原生 macOS

当前源码的 podspec 已支持 macOS 10.13+。本版本发布前可通过本地仓库接入：

```ruby
platform :osx, '10.13'
pod 'MXLogger', :path => '/path/to/MXLogger'
pod 'MXLoggerCore', :path => '/path/to/MXLogger'
```

SwiftPM 使用 [mxlogger-spm](https://github.com/coder-dongjiayi/mxlogger-spm.git)，
`spm/Package.swift` 已声明 iOS 12+、macOS 10.13+。两端共用原生 API；macOS 需显式调用
`removeExpireData` 清理，`shouldRemoveExpiredDataWhenEnterBackground` 不生效。
Flutter macOS 已通过共享的 `darwin/` 插件接入（Flutter 3.7+、macOS 10.14+），使用同一套 Dart API。

### 原生 macOS Demo

原生示例位于 `platform/macOS/MXLoggerDemo`，使用 **AppKit + Swift + Main.storyboard**，
入口、主页、文件列表、日志详情以及列表单元格均可在 Storyboard 中编辑。
界面沿用 iOS / Android / Flutter Demo 的 Logo、紫色状态卡、分组功能和中英文切换，
并直接复用 iOS Demo 的 Logo 和语言资源。

```bash
pod install --project-directory=platform/macOS/MXLoggerDemo
open platform/macOS/MXLoggerDemo/MXLoggerDemo.xcworkspace
```

在 Xcode 选择 `MXLoggerDemo` scheme 和 `My Mac` 后运行。
Demo 从当前仓库加载原生 Pods，无需先发布 2.3.0，也不依赖 Flutter。
默认参数与其他三个 Demo 一致：命名空间 `com.djy.mxlogger`、按小时切分、
AES-CFB-128 加密、保留 7 天、大小上限 10 MB。

功能包括五级日志、网络 JSON、通用写入、Token 写入、等级与开关设置、
10 万条性能测试、多线程 / 多进程并发写入与数量及顺序校验、手动清理、实例重建，
以及带等级 / 关键词筛选和完整内容查看的日志浏览器。
macOS 不提供后台自动清理开关；Release 中控制台开关会置灰。
`pod install` 会为本地 Xcode 生成 `Configurations/SDK.xcconfig`，使 Demo 的部署目标适配当前 SDK。

单独验证 Demo：

```bash
bash scripts/verify_macos_demo.sh
```

该检查编译 Debug / Release，并实际执行双进程加密读写、Token、清理和重开校验。
Debug 还会加载 Storyboard 检查页面连接、导航、双语及筛选，生成应用自身视图的预览。
日志和预览位于 `build/macos-native-demo/`。

### 原生 Windows Demo

原生示例位于 [`platform/Windows/MXLoggerDemo`](platform/Windows/MXLoggerDemo/README.md)，使用 **Win32 + C++17**，
直接链接本仓库 Core。包含中英文界面、初始化配置、五级日志与 JSON / Token 写入、
线程 / 双进程数量及顺序校验、10 万条性能测试、清理重建和带筛选的日志浏览器。

```powershell
cmake -S platform/Windows/MXLoggerDemo -B build/windows-demo -A x64
cmake --build build/windows-demo --config Debug --parallel
.\build\windows-demo\bin\Debug\MXLoggerDemo.exe
```

Windows 10/11 x64，需 Visual Studio C++ 桌面开发工具和 CMake 3.20+。
手动运行 `verify-logger` 会在 Windows Debug / Release 构建并运行真实窗口自测，
日志在 GitHub Actions 步骤中查看；全部平台验证通过后，上传 Release 的 `MXLoggerDemo.exe`。
Mac 可编辑代码并验证共用日志操作，Windows GUI 的编译和运行由 Windows CI 验证。

Windows C++ 工程可通过原生 **NuGet 包 `MXLogger.Native`** 或 **vcpkg overlay `mxlogger`** 接入。
当前由手动 CI 生成 2.3.0 的 nupkg，支持 x64、MD / MT 与 Debug / Release；
公共 NuGet / vcpkg registry 尚未发布，安装步骤见 [Windows SDK](platform/Windows/README.md)。

### Flutter macOS Demo

Flutter 桌面示例位于 `platform/flutter_mxlogger/example`，复用手机端的落地页、紫色状态卡、
分组功能、中英文切换、文件列表及日志查看器，补充桌面窗口、设置弹窗和独立 Finder 入口。
支持五级 / JSON / Token 写入、10 万条性能测试、多 isolate 并发校验、手动清理和日志筛选。
macOS 隐藏后台清理开关；多 isolate 属于同一个进程，多进程演示见上方原生 Demo。

在仓库根目录运行，无需先发布原生 2.3.0：

```bash
bash scripts/run_flutter_macos_demo.sh
# Flutter 不在 PATH 时，在命令前设置 FLUTTER_BIN=/path/to/flutter/bin/flutter
bash scripts/run_flutter_macos_demo.sh build --release
bash scripts/run_flutter_macos_demo.sh test
```

启动脚本仅为当前命令启用本地 CocoaPods，Demo 自动适配本机 Xcode SDK 的最低构建版本。
界面检查使用临时日志目录，并在 `platform/flutter_mxlogger/example/screenshots/macos-*.png` 保存预览。
详细说明见 [Flutter Demo](platform/flutter_mxlogger/example/README.md)。

### macOS 回归验证与发布准备

在安装了 Xcode（含 iOS SDK）、CocoaPods、Python 3 和 Flutter 3.44+ 的 Mac 上运行：

```bash
python3 scripts/verify_macos_support.py
# Flutter 不在 PATH 时：
python3 scripts/verify_macos_support.py --flutter /path/to/flutter/bin/flutter
```

脚本依次运行 Core 测试（包含真实多进程读写、清理、进程退出恢复）、Objective-C / Swift
API 测试、原生 macOS Demo、Flutter 单元测试、桌面 Demo 界面流程、iOS 设备与模拟器桥接编译，以及 macOS CocoaPods / SwiftPM
两种接入方式的 Debug 集成测试和 Release 加密读写。Release 还会检查所有桥接导出符号。

测试工程生成在 `build/macos-validation/run-*/`，使用本地原生源码，因此原生 2.3.0
尚未发布时也可验证。发布用的依赖地址、版本和示例锁文件不会被改写，Flutter 全局配置也不变。
测试工程的部署目标会根据当前 Xcode SDK 的最低支持版本调整；库自身的 macOS 10.13
和 Flutter 插件的 macOS 10.14 声明保持不变。该检查不能替代旧系统上的实际运行验证。

可用 `--package-manager pods` 或 `--package-manager spm` 单独验证一种接入方式，
`--skip-native` 跳过 Core / 原生 Apple 测试。`--offline` 仅表示 Dart 包使用本地缓存，
Flutter 引擎缓存和 CocoaPods 索引仍需提前准备。日志和结果位于对应运行目录的 `logs/`。
此脚本使用 Flutter 3.44+ 切换测试工程的接入方式；插件的最低 Flutter 要求仍为 3.7。
成功后默认删除占用数 GB 的 Flutter 测试工程并保留日志；加 `--keep-builds` 可保留构建现场，失败时也会保留。

Android 原生回归使用 NDK、CMake 和 Ninja，编译四种 ABI，并检查没有引入 macOS 的进程锁：

```bash
ANDROID_NDK_HOME=/path/to/android-sdk/ndk/27.0.12077973 bash scripts/verify_android_native.sh
```

`.github/workflows/verify-logger.yml` **仅手动触发**，依次执行三个阶段：

1. C++ Core 单元测试：Windows、macOS、Linux 的 Debug / Release。
2. 各平台原生及 Flutter 接口测试：iOS、Android、macOS、Windows；全部 Core 测试通过后才开始。
3. Release SDK 与 Demo 出包：全部接口测试通过后才开始。

| 平台 | 文件 |
|---|---|
| Windows | `MXLoggerDemo.exe`（x64） |
| macOS | `MXLoggerDemo-macOS-Release.dmg`（Apple Silicon + Intel） |
| Android | `MXLoggerDemo-android-Release.apk`（包含四种 ABI） |
| Flutter Windows | `MXLoggerFlutterDemo-windows-x64-Release`（EXE、DLL 和 `data/`） |
| Windows SDK | `MXLogger.Native.2.3.0.nupkg`、本地 vcpkg SDK 和 `flutter_mxlogger-windows-prebuilt` |

安装文件通过 [`archive: false`](https://github.com/actions/upload-artifact/tree/v7#upload-an-individual-file-unzipped) 直接上传原文件，不增加 ZIP 包装；可下载产物保留 7 天，不再单独上传 Logs。Flutter Windows Demo 是包含运行依赖的完整目录包，解压后运行 `MXLoggerFlutterDemo.exe`。
macOS DMG 支持拖入 Applications，采用 ad-hoc 签名，未进行 Apple 公证。
Android APK 使用测试密钥签名，构建类型为 Release；不同 CI 运行的测试密钥可能不同，覆盖安装失败时需先卸载旧 Demo。
Android 设备上的运行验证需另行进行。

本地构建同样的安装文件：

```bash
bash scripts/build_macos_demo_dmg.sh
ANDROID_HOME=/path/to/android-sdk bash scripts/verify_android_demo.sh test
ANDROID_HOME=/path/to/android-sdk bash scripts/verify_android_demo.sh package
```

Android 使用 JDK 17、NDK `27.0.12077973`、CMake `3.22.1`、SDK 平台 31 / 33 和 Build Tools `34.0.0`。

2.3.0 发布时，先同步 `mxlogger-spm` 镜像，并使主仓库和镜像的 `v2.3.0` 标签可用；
随后发布 `MXLoggerCore`、`MXLogger` 和 Android 2.3.0，最后发布 Flutter 包。
发布 Flutter 前运行 `scripts/pub_flutter_mxlogger.sh --dry-run`，并在依赖正式可用后验证远程接入。

## Android

```groovy
implementation 'io.github.coder-dongjiayi:mxlogger:2.3.0'
```

## Flutter

```yaml
dependencies:
  flutter_mxlogger: ^2.3.0
  mxlogger_analyzer_lib: ^2.0.0   # 可选：app 内实时查看日志
```

原生依赖会自动引入，无需手动配置：iOS 端 CocoaPods 依赖 `MXLogger` → `MXLoggerCore`，
Android 端 Gradle 依赖 `io.github.coder-dongjiayi:mxlogger`。

---

# 快速开始

## iOS

```objective-c
MXLogger *logger = [MXLogger initializeWithNamespace:@"com.yourdomain.logger"
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:@"mxlog"
                                         fileHeader:@"{\"app_version\":\"2.0.0\"}"
                                           cryptKey:@"abcuioqbsdguijlk"   // 16 字节
                                                 iv:@"bccuioqbsdguijiv"];

logger.consoleEnable = YES;                 // 仅开发期开启，性能测试/线上设为 NO
logger.maxDiskAge   = 60 * 60 * 24 * 7;     // 最多保留 7 天
logger.maxDiskSize  = 1024 * 1024 * 10;     // 最多占用 10M
logger.level        = 0;                    // 0:debug 全部写入文件

// 多个 tag 用英文逗号分隔
[logger debugWithName:@"login" msg:@"开始校验本地 token" tag:@"login,service"];
[logger infoWithName:@"network" msg:responseJSON tag:@"network,POST,200"];
[logger warnWithName:@"network" msg:@"第 2 次重试" tag:@"network"];
[logger errorWithName:@"flutter" msg:stack tag:@"crash"];
[logger fatalWithName:@"database" msg:@"数据库连接丢失" tag:@"db,fatal"];

NSLog(@"日志目录 %@", logger.diskCachePath);
```

## Android

```java
MXLogger logger = MXLogger.initialize(
        context,
        "com.yourdomain.logger",              // nameSpace
        null,                                 // diskCacheDirectory，null 用默认目录
        MXStoragePolicyType.YYYY_MM_DD,
        "mxlog",                              // fileName
        "{\"app_version\":\"2.0.0\"}",        // fileHeader
        "abcuioqbsdguijlk",                   // cryptKey，16 字节
        "bccuioqbsdguijiv");                  // iv

logger.setConsoleEnable(true);
logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

// 注意 Android 端 tag 在第一个参数：debug(tag, name, msg)
logger.debug("login,service", "login", "开始校验本地 token");
logger.info("network,POST,200", "network", responseJson);
logger.warn("network", "network", "第 2 次重试");
logger.error("crash", "flutter", stack);
logger.fatal("db,fatal", "database", "数据库连接丢失");

Log.d("MXLogger", "日志目录 " + logger.getDiskCachePath());
```

## Flutter

```dart
final MXLogger logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyyMMdd,
  fileHeader: jsonEncode(deviceInfo),
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 字节
  iv: "bccuioqbsdguijiv",         // 不填默认与 cryptKey 一致
);

logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

logger.debug("开始校验本地 token", name: "login", tag: "login,service");
logger.info(jsonEncode(response), name: "network", tag: "network,POST,200");
logger.warn("第 2 次重试", name: "network", tag: "network");
logger.error(stack, name: "flutter", tag: "crash");
logger.fatal("数据库连接丢失", name: "database", tag: "db,fatal");

debugPrint("日志目录 ${logger.diskcachePath}");
```

---

# API 一览

无需创建 logger 即可读取当前链接的 C++ Core 版本，当前为 `2.3.0`。
Core 版本与各平台封装包版本独立，各 Demo 会动态展示该值。

| 平台 | 调用方式 |
|---|---|
| Windows / C++ | `mx_logger::version()` |
| iOS / macOS（Objective-C） | `[MXLogger coreVersion]` |
| iOS / macOS（Swift） | `MXLogger.coreVersion()` |
| Android（Java/Kotlin） | `MXLogger.coreVersion()` |
| Flutter（原生平台） | `MXLogger.coreVersion()` |

三端共通的两个概念：一个 logger 由 **nameSpace + diskCacheDirectory** 唯一确定，底层 C++ 对象按这一对
去重；这一对的 md5 就是 **loggerToken**——大型 app 组件化时把它传给子模块，子模块用类方法写日志，不必传
logger 对象。

原生 macOS Core 支持多个进程协作访问同一日志目录：写入前获取目录级文件锁，刷新有效长度和
映射容量；不逐条检查路径是否被外部删除或替换。读取时复制有效数据快照后解锁解析。各进程须使用本协议及一致的加密参数，
实际目录必须共享且可访问。不同日志目录互不阻塞；iOS、Android 保持原来的文件访问流程，
Windows Core 使用 `LockFileEx` 协调同目录多进程访问，可以在连续写入间保留映射，
活动文件保护由独立的协调文件锁维持。原生和 Flutter Windows 接入均由手动触发的 `verify-logger` CI 验证；
Flutter 使用预编译 DLL。

macOS / Windows Core 的 `.mxlogger.lock` 是协调文件，不计入日志列表或大小，也不会被清理；logger 存活时请勿手动删除。
过期/容量清理、`removeBeforeAllData` 和 `removeAllData` 均保留当前文件及其他活跃 logger 持有的文件。
iOS / Android 的清理也保留自身当前文件。外部删除 POSIX 文件后，现有 logger 允许继续写旧映射，
不自动按原路径重建；释放并重新初始化 logger 时正常打开文件。`.mx` 格式保持不变，没有新增 CRC 或断电持久性保证；
macOS / Windows 写入返回码 `-4` 表示文件锁失败或超过 32 位有效长度上限，详情见 `errorDesc`。

> **废弃说明。** `loggerToken` 之前叫 `loggerKey`，容易和加密用的 `cryptKey` 混淆。iOS / Android / Flutter
> 三端所有 `loggerKey` 系列 API 仍然可用，内部直接转发到对应的 `loggerToken` 版本，但已标记为废弃，
> **后续版本一定会移除**。请尽早迁移：`loggerKey` → `loggerToken`，`xxxWithLoggerKey:` → `xxxWithLoggerToken:`，
> `getLoggerKey()` → `getLoggerToken()`，`logLoggerKey` → `logLoggerToken`，`destroyWithLoggerKey` → `destroyWithLoggerToken`。

<a name="ios-api"></a>
## iOS —— `MXLogger`（Objective-C）

### 创建与释放

| API | 说明 |
| --- | --- |
| `+ initializeWithNamespace:` | iOS 默认目录 `Library/com.mxlog.LoggerCache`；macOS 为 `Application Support/<bundle-id>/MXLogger` |
| `+ initializeWithNamespace:fileHeader:` | 指定文件头信息 |
| `+ initializeWithNamespace:cryptKey:iv:fileHeader:` | 加密 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:` | 指定存储策略和文件名 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 存储策略 + 加密 |
| `+ initializeWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 全参数 |
| `- initWithNamespace:fileHeader:` | 实例初始化方法，参数组合同上 |
| `- initWithNamespace:diskCacheDirectory:fileHeader:` | |
| `- initWithNamespace:cryptKey:iv:fileHeader:` | |
| `- initWithNamespace:storagePolicy:fileName:fileHeader:` | |
| `- initWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 完整初始化方法，其他方法最终都调它 |
| `+ destroyWithNamespace:` | 按 nameSpace 释放（默认目录） |
| `+ destroyWithNamespace:diskCacheDirectory:` | 按 nameSpace + 目录释放 |
| `+ destroyWithLoggerToken:` | 按 loggerToken 释放 |
| `+ valueForLoggerToken:` | 取已存在的 logger，不存在返回 `nil` |
| `+ destroyWithLoggerKey:` / `+ valueForLoggerKey:` | **已废弃**，转发到上面的 `LoggerToken` 版本，后续版本将移除 |

### 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `enable` | `BOOL` | 日志写入总开关 |
| `consoleEnable` | `BOOL` | 控制台输出，默认关闭；Release/Profile 构建已在编译期整段裁掉（需保留则定义 `MXLOGGER_CONSOLE_ENABLED=1`） |
| `level` | `NSInteger` | 写入文件的最低等级，0 debug … 4 fatal |
| `maxDiskAge` | `NSUInteger` | 最大存储时长（秒），0 不限制 |
| `maxDiskSize` | `NSUInteger` | 最大总字节数，0 不限制 |
| `shouldRemoveExpiredDataWhenEnterBackground` | `BOOL` | iOS 进入后台是否自动清理，默认 `YES`；macOS 不生效 |
| `diskCachePath` | `NSString`（只读） | 日志目录 |
| `logSize` | `NSUInteger`（只读） | 当前占用字节数 |
| `loggerToken` | `NSString`（只读） | nameSpace + 目录的 md5 |
| `loggerKey` | `NSString`（只读） | **已废弃**，值与 `loggerToken` 相同，后续版本将移除 |

### 写入

| API | 说明 |
| --- | --- |
| `- logWithLevel:name:msg:tag:` | 返回 0 成功，-1 扩容失败 / -2 解除映射失败 / -3 映射失败 |
| `- debugWithName:msg:tag:` | 等级 0 |
| `- infoWithName:msg:tag:` | 等级 1 |
| `- warnWithName:msg:tag:` | 等级 2 |
| `- errorWithName:msg:tag:` | 等级 3 |
| `- fatalWithName:msg:tag:` | 等级 4 |
| `+ debugWithLoggerToken:name:msg:tag:` | 通过 loggerToken 写入，无需持有 logger 对象 |
| `+ infoWithLoggerToken:name:msg:tag:` | |
| `+ warnWithLoggerToken:name:msg:tag:` | |
| `+ errorWithLoggerToken:name:msg:tag:` | |
| `+ fatalWithLoggerToken:name:msg:tag:` | |
| `+ xxxWithLoggerKey:name:msg:tag:` | **已废弃**，转发到 `xxxWithLoggerToken:`，后续版本将移除 |

### 文件、清理与解析

| API | 说明 |
| --- | --- |
| `- logFiles` | 字典数组：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `- errorDesc` | 最近一次写入失败的错误信息 |
| `- removeExpireData` | 先删过期文件，总大小仍超 `maxDiskSize` 则从最旧的继续删；正在写入的文件不删 |
| `- removeAllData` | 清理闲置日志，保留正在使用的文件 |
| `- removeBeforeAllData` | 删除除当前正在写入外的所有文件 |
| `+ selectWithDiskCacheFilePath:cryptKey:iv:` | 解析日志文件（时间倒序）：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code` |

### `MXStoragePolicyType`（iOS / Objective-C）

`MXStoragePolicyYYYYMMDD`（按天，默认）· `MXStoragePolicyYYYYMMDDHH`（按小时）·
`MXStoragePolicyYYYYWW`（按周）· `MXStoragePolicyYYYYMM`（按月）

<a name="android-api"></a>
## Android —— `com.dongjiayi.mxlogger.MXLogger`（Java）

### 创建与释放

| API | 说明 |
| --- | --- |
| `MXLogger(Context, String nameSpace, String diskCacheDirectory, MXStoragePolicyType, String fileName, String fileHeader, String cryptKey, String iv)` | 完整构造方法 |
| `MXLogger(Context, String nameSpace, String fileHeader)` | 默认目录 |
| `MXLogger(Context, String nameSpace, String fileHeader, String cryptKey, String iv)` | 加密 |
| `MXLogger(Context, String fileHeader, String nameSpace, String diskCacheDirectory)` | 自定义目录 |
| `static MXLogger initialize(Context, nameSpace, diskCacheDirectory, storagePolicy, fileName, fileHeader, cryptKey, iv)` | 全参数 |
| `static MXLogger initialize(Context, nameSpace, fileHeader)` | |
| `static MXLogger initialize(Context, nameSpace, fileHeader, cryptKey, iv)` | |
| `static void destroy(Context, String nameSpace, String diskCacheDirectory)` | 按 nameSpace + 目录释放 |
| `static void destroy(String loggerToken)` | 按 loggerToken 释放 |

### 配置与状态

配置项不在 Java 侧缓存：所有 getter 直接查询 native（多个 Java 实例可能共享同一个 native 对象，
native 是唯一事实源）。

| API | 说明 |
| --- | --- |
| `void setEnable(boolean)` / `boolean isEnable()` | 日志写入总开关 |
| `void setConsoleEnable(boolean)` / `boolean isConsoleEnable()` | 控制台输出 |
| `void setLevel(int)` / `int getLevel()` | 写入文件的最低等级，0 debug … 4 fatal |
| `void setMaxDiskAge(long)` / `long getMaxDiskAge()` | 最大存储时长（秒），0 不限制 |
| `void setMaxDiskSize(long)` / `long getMaxDiskSize()` | 最大总字节数，0 不限制 |
| `long getLogSize()` | 当前占用字节数 |
| `String getDiskCachePath()` | 日志目录 |
| `String getLoggerToken()` | nameSpace + 目录的 md5 |
| `String getLoggerKey()` | **已废弃**，值与 `getLoggerToken()` 相同，后续版本将移除 |
| `String getErrorDesc()` | 最近一次写入失败的错误信息 |

### 写入

注意参数顺序：Android 端 **tag 在第一个参数**。

| API | 说明 |
| --- | --- |
| `int debug(String tag, String name, String msg)` | 等级 0 |
| `int info(String tag, String name, String msg)` | 等级 1 |
| `int warn(String tag, String name, String msg)` | 等级 2 |
| `int error(String tag, String name, String msg)` | 等级 3 |
| `int fatal(String tag, String name, String msg)` | 等级 4 |
| `int log(String tag, int level, String name, String msg)` | 返回 0 成功，-1 / -2 / -3 失败 |
| `static int log(String loggerToken, String tag, int level, String name, String msg)` | 通过 loggerToken 写入 |

### 文件、清理与解析

| API | 说明 |
| --- | --- |
| `String[] logFiles()` | 每个元素是一个文件的 JSON 字符串：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `void removeExpireData()` | 先删过期文件，超出 `maxDiskSize` 再从最旧的继续删。Android 端没有生命周期钩子，需自行调用（如 `onStop`） |
| `void removeAll()` | 清理闲置日志，保留正在使用的文件 |
| `void removeBeforeAllData()` | 删除除当前正在写入外的所有文件 |
| `static String[] selectWithFilePath(String diskCacheFilePath, String cryptKey, String iv)` | 解析日志文件，每个元素是一条日志的 JSON 字符串（时间倒序） |

### `MXStoragePolicyType`（Android / Java）

`YYYY_MM_DD`（按天，默认）· `YYYY_MM_DD_HH`（按小时）· `YYYY_WW`（按周）· `YYYY_MM`（按月）

Android Java 仍使用以上大写枚举名。Flutter / Dart 使用 `yyyyMMdd`、`yyyyMMddHH`、`yyyyWw`、`yyyyMM`，详见 [Flutter API](#flutter-api)。

<a name="flutter-api"></a>
## Flutter —— `flutter_mxlogger`

所有读写都走 `dart:ffi`，MethodChannel 只在 `initialize` 时用来获取平台默认目录。

### 创建与释放

| API | 说明 |
| --- | --- |
| `static Future<MXLogger> initialize({required String nameSpace, String? directory, bool consoleEnable = false, MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyyMMdd, String? fileName, String? fileHeader, String? cryptKey, String? iv})` | 推荐用法，自动获取平台默认目录（iOS `Library/com.mxlog.LoggerCache/nameSpace`，Android `files/com.mxlog.LoggerCache/nameSpace`） |
| `MXLogger({required String nameSpace, required String directory, ...})` | 同步构造方法，必须显式给目录 |
| `static void destroy({required String nameSpace, String? directory})` | 释放；会先失效对应的 Dart 实例，避免 use-after-free |
| `static void destroyWithLoggerToken(String loggerToken)` | 按 loggerToken 释放 |
| `static void destroyWithLoggerKey(String loggerKey)` | **已废弃**，转发到 `destroyWithLoggerToken`，后续版本将移除 |

### Getter

| Getter | 类型 | 说明 |
| --- | --- | --- |
| `enable` | `bool` | 日志写入是否开启 |
| `consoleEnable` | `bool` | 控制台输出是否开启 |
| `diskcachePath` | `String` | 日志目录（directory + nameSpace） |
| `diskcacheErrorPath` | `String` | 本地错误文件 `error.txt` 路径 |
| `loggerToken` | `String?` | nameSpace + 目录的 md5 |
| `loggerKey` | `String?` | **已废弃**，值与 `loggerToken` 相同，后续版本将移除 |
| `logSize` | `int` | 当前占用字节数 |
| `logFiles` | `List<MXFileEntity>` | 日志文件列表 |
| `errorDesc` | `String?` | 最近一次 native 写入错误，无错误返回 `null` |
| `cryptKey` / `iv` | `String?` | 初始化时传入的加密参数，可直接交给解析器 |

### 开关与磁盘管理

| API | 说明 |
| --- | --- |
| `void setEnable(bool enable)` | 日志写入总开关 |
| `void setConsoleEnable(bool enable)` | 控制台输出；release/profile 构建整段被 tree-shake |
| `void setLevel(int lvl)` | 写入文件的最低等级，0 debug … 4 fatal |
| `void setMaxDiskAge(int age)` | 最大存储时长（秒），0 不限制 |
| `void setMaxDiskSize(int size)` | 最大总字节数，0 不限制 |
| `void shouldRemoveExpiredDataWhenEnterBackground(bool should)` | 移动端进入后台是否自动清理，默认 `true`；macOS 需手动清理 |
| `void removeExpireData()` | 先删过期文件，超出大小限制再从最旧的继续删 |
| `void removeAll()` | 清理闲置日志，保留正在使用的文件 |
| `void removeBeforeAllData()` | 删除除当前正在写入外的所有文件 |
| `int getLogSize()` / `String getDiskcachePath()` / `String? getLoggerToken()` / `List<MXFileEntity> getLogFiles()` | 上面几个 getter 的方法形式 |

### 写入

| API | 说明 |
| --- | --- |
| `int debug(String msg, {String? name, String? tag})` | 等级 0 |
| `int info(String msg, {String? name, String? tag})` | 等级 1 |
| `int warn(String msg, {String? name, String? tag})` | 等级 2 |
| `int error(String msg, {String? name, String? tag})` | 等级 3 |
| `int fatal(String msg, {String? name, String? tag})` | 等级 4 |
| `int log(int lvl, String msg, {String? name, String? tag})` | 返回 0 成功，-1 扩容失败 / -2 解除映射失败 / -3 映射失败 |
| `static void logLoggerToken(String? loggerToken, int lvl, String msg, {String? name, String? tag})` | 通过 loggerToken 写入 |
| `static void logLoggerKey(...)` | **已废弃**，转发到 `logLoggerToken`，后续版本将移除 |
| `static void debugLog(String? loggerToken, String msg, {String? name, String? tag})` | 另有 `infoLog` / `warnLog` / `errorLog` / `fatalLog`，签名一致 |

### 写入失败记录与解析

| API | 说明 |
| --- | --- |
| `void writeFail({required int code, required String errorDesc, String? other})` | `log` 返回值 != 0 时调用，把失败信息以 JSON 行追加到 `diskcacheErrorPath` |
| `void deleteFailFile()` | 删除本地错误文件 |
| `void closeFailFile()` | 关闭错误文件的写入流 |
| `static List<Map<String, dynamic>> selectLogmsg({required String diskcacheFilePath, String? cryptKey, String? iv})` | 解析日志文件（时间倒序）：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code`；`error_code == "1"` 表示该条解析失败（多为 cryptKey 或 iv 不正确） |
| `static List<Map<String, dynamic>> selectLogfiles({required String directory})` | **未实现**，各平台均返回空列表，获取文件信息请用 `logFiles` |

### `MXFileEntity`

`name`（`String?`）· `size`（`int`，字节）· `createTimeStamp` / `lastTimeStamp`（`int`，秒）·
`createTime` / `lastTime`（`DateTime`，由时间戳换算）

### `MXStoragePolicyType`（Flutter / Dart）

`yyyyMMdd`（按天，默认）· `yyyyMMddHH`（按小时）· `yyyyWw`（按周）· `yyyyMM`（按月）

<a name="analyzer-api"></a>
## 解析器 —— `mxlogger_analyzer_lib`

### 嵌入宿主 app：`MXAnalyzer`

| API | 说明 |
| --- | --- |
| `static void initialize({String? databasePath, MXPrefs? prefs})` | 可选预配置：sqlite 目录（不传默认 `getApplicationSupportDirectory()`）、主题/语言/解密参数的持久化实现（不传只存内存） |
| `static Future<void> showDebug(OverlayState overlayState, {required String diskcachePath, required List<MxCryptPair> cryptPairs, required MXShareHandler onShare, String? databasePath})` | 显示悬浮球（拖动移动、单击开弹窗、双击移除）；悬浮球已存在时重复调用直接忽略 |
| `static void dismiss()` | 移除悬浮球并释放数据库 |

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,
  // 日志未加密传空数组；换过密钥可传多组，解析时逐条按顺序尝试，
  // 所以同一个文件里用不同 Key/IV 写的记录也能全部解出来
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  onShare: _shareWithSharePlus,   // 返回 false 则降级为复制到剪贴板
);

MXAnalyzer.dismiss();
```

打开弹窗**不会**自动解析：由用户点「刷新」扫描 `diskcachePath` 下的 `.mx` 文件，每次刷新都清空数据库
重新解析，所见即本次扫描的全量结果。结果落在 sqlite，App 重启后再打开仍能看到上次的结果。

### 宿主相关类型

| 类型 | 说明 |
| --- | --- |
| `MxCryptPair({required String key, String iv = ""})` | 一组解密参数；`iv` 为空时按 native 约定回退为 `key` |
| `MXShareHandler` = `Future<bool> Function(MXShareRequest)` | 分享实现由宿主注入，返回 `false` 降级为复制到剪贴板 |
| `MXShareRequest` | `title` / `text` / `fileName`（非空表示分享文本文件）/ `origin`（触发控件的屏幕矩形，iPad/macOS 的 popover 分享面板需要） |
| `MXHost({required MXPrefs prefs, MXPickLogFiles? pickLogFiles, MXDropTargetBuilder? dropTargetBuilder, MXShareHandler? share})` | 桌面壳的能力注入；缺哪个能力就少哪个入口，而不是抛异常 |
| `MXPrefs` / `MXMemoryPrefs` | 设置持久化接口，默认使用内存实现 |
| `MXStore` / `MXScope` / `MXState` / `MXAsyncState` | 基于 stream 的轻量状态管理，自定义嵌入方式时使用 |
| `MXLoggerAnalyzerApp` | 完整的解析器 app，自定义桌面壳时使用 |

---

# 存储策略与日志等级

**存储策略**决定日志文件如何切分和命名：

| 策略 | 文件名 | |
| --- | --- | --- |
| 按天（默认） | `2023-01-11_mxlog.mx` | 一天一个文件 |
| 按小时 | `2023-01-11-15_mxlog.mx` | 一小时一个文件 |
| 按周 | `2023-01-02w_mxlog.mx` | `02w` 指一年中的第 2 周 |
| 按月 | `2023-01_mxlog.mx` | 一个月一个文件 |

**日志等级**为 `0:debug 1:info 2:warn 3:error 4:fatal`。设置 level = n 表示只有 >= n 的日志会被写入
文件：比如 `level = 2`，`debug` 和 `info` 会被丢弃，只写入 `warn` `error` `fatal`。该字段只针对**磁盘
写入**生效，开启控制台输出后控制台仍会打印全部日志。

**控制台输出**只面向开发期。它会影响写入效率，做性能测试时务必关闭；线上包三端都会在编译期把这段裁掉。

**加密**使用 AES-CFB-128，代码来自 [MMKV](https://github.com/Tencent/MMKV/tree/master/Core/aes)，
汇编实现，最大程度保障写入性能。`cryptKey` 和 `iv` 为 16 字节——超过自动截断，不足补 0；`iv` 不填时默认
与 `cryptKey` 一致。这两个值要留好：解析器需要同一组参数才能读回文件。

**文件头信息**（`fileHeader`）在文件创建时写入一次，适合放环境信息（app 版本、平台、设备信息），
解析器会把它展开成标量紧凑网格 + JSON 树。

---

# 性能测试

### 对比 Xlog 和 Logan

写入测试，以下仅为 iOS 端结果（性能测试 demo 代码点[这里](./性能测试demo.zip)下载）：

- 测试设备 iPhone 11，系统版本 14.6，Xcode Build Configuration 为 release
- 每条数据约 134 字节，for 循环 10 万次
- 测试 10 次取平均值

| | MXLogger | Xlog | Logan |
| --- | --- | --- | --- |
| 写入耗时 | **约 0.13s** | 约 0.57s | 约 14.0s |
| 文件体积 | 14008320 byte (14M) | 905753 byte (0.9M) | 922452 byte (0.9M) |

<img src="./icon/haoshi.jpg" alt="耗时对比" width="520" />

Logan 和 Xlog 对数据做了压缩，实际体积会小很多。日志压缩在 MXLogger 的后续迭代计划里。

---

# 注意事项

- 日志目录**不要**设置在可能被系统清理的目录，比如 iOS 的 `Library/Caches`。MXLogger 只在启动时创建
  目录，不会在每次写入时检测——如果 app 运行中目录被系统清理，程序不会报错也不会闪退，但日志也不会被记录。
- 一个 **nameSpace + diskCacheDirectory** 只对应一个 logger：重复初始化拿到的是同一个 native 对象的
  包装，通过任意一个改配置对其他实例同样生效。
- `nameSpace` 建议使用域名反转保证唯一性。
- 组件化工程把 **loggerToken** 传给子模块，子模块用类方法写日志，不必传 logger 对象。
- `maxDiskAge` / `maxDiskSize` 不是每次写入都校验：清理发生在 `removeExpireData`（iOS 与 Flutter 进入
  后台自动调用，Android 需自行调用）。

  

# 开源协议

MXLogger 使用 BSD 3-Clause 协议，详见 [LICENSE.TXT](./LICENSE.TXT)。
