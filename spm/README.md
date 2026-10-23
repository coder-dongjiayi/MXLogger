# mxlogger-spm

Swift Package Manager distribution of [MXLogger](https://github.com/coder-dongjiayi/MXLogger),
a high-performance cross-platform logger built on mmap with AES-CFB-128 encryption.

> **This repository is a generated mirror.** Every file here is produced by
> `scripts/sync_spm_mirror.sh` in the main repository and overwritten on each release.
> Do not open pull requests or commit here; report issues and contribute at
> [coder-dongjiayi/MXLogger](https://github.com/coder-dongjiayi/MXLogger).
>
> **本仓库是自动生成的镜像。** 所有文件由主仓库的 `scripts/sync_spm_mirror.sh` 生成，每次发版整体覆盖。
> 请不要在这里提 PR 或提交代码，问题反馈与贡献请前往主仓库
> [coder-dongjiayi/MXLogger](https://github.com/coder-dongjiayi/MXLogger)。

## Installation

Xcode: **File > Add Package Dependencies...**, paste

```
https://github.com/coder-dongjiayi/mxlogger-spm.git
```

and add the **MXLogger** product to your app target.

Starting with **2.2.0**, supported deployment targets: **iOS 12+** and **macOS 10.13+**. macOS uses the same
Objective-C and Swift API as iOS. Its default directory is
`Application Support/<bundle-id>/MXLogger` (the process name is used if the bundle ID is absent).
On macOS, call `removeExpireData()` explicitly to apply age/size cleanup;
`shouldRemoveExpiredDataWhenEnterBackground` has no effect.

自 **2.2.0** 起支持 **iOS 12+、macOS 10.13+**，两端共用 Objective-C / Swift API。macOS 默认写入
`Application Support/<bundle-id>/MXLogger`，无 bundle ID 时使用进程名。
macOS 需手动调用 `removeExpireData()` 清理；`shouldRemoveExpiredDataWhenEnterBackground` 不生效。

Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coder-dongjiayi/mxlogger-spm.git", from: "2.2.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "MXLogger", package: "mxlogger-spm")]
    ),
]
```

## Usage

Swift:

```swift
import MXLogger

let logger = MXLogger.shared(namespace: "app", cryptKey: "your-16-byte-key", iv: nil, fileHeader: nil)
logger.info(name: "network", message: "request finished", tag: "http")
```

Objective-C:

```objc
#import <MXLogger/MXLogger.h>

MXLogger *logger = [MXLogger initializeWithNamespace:@"app"];
[logger infoWithName:@"network" msg:@"request finished" tag:@"http"];
```

Full documentation, storage policies, encryption details and the desktop log analyzer live in
the main repository: [README](https://github.com/coder-dongjiayi/MXLogger#readme) ·
[中文文档](https://github.com/coder-dongjiayi/MXLogger/blob/main/README_CN.md).

## Products

| Product        | Contents                                                   |
| -------------- | ---------------------------------------------------------- |
| `MXLogger`     | Objective-C API (`MXLogger.h`), depends on `MXLoggerCore`  |
| `MXLoggerCore` | C/C++ engine (mmap sink, AES-CFB-128, FlatBuffers records) |

Versions follow the main repository tags (`vX.Y.Z`). CocoaPods users should keep using the
`MXLogger` pod, which is published from the main repository.

## License

BSD 3-Clause, see [LICENSE](LICENSE).
