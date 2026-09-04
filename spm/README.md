# MXLogger-Apple

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
https://github.com/coder-dongjiayi/MXLogger-Apple.git
```

and add the **MXLogger** product to your app target.

Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/coder-dongjiayi/MXLogger-Apple.git", from: "2.0.1"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [.product(name: "MXLogger", package: "MXLogger-Apple")]
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
