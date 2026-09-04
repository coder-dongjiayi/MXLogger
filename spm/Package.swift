// swift-tools-version: 5.9
//
// MXLogger Swift Package 清单。此文件的源在主仓库 coder-dongjiayi/MXLogger 的 spm/ 目录，
// 由 scripts/sync_spm_mirror.sh 复制到镜像仓库 coder-dongjiayi/MXLogger-Apple 根目录。
// 请勿直接在镜像仓库修改。
//
// Swift Package manifest for MXLogger. The source of truth is spm/ in the main repository
// coder-dongjiayi/MXLogger; scripts/sync_spm_mirror.sh copies it to the root of the mirror
// repository coder-dongjiayi/MXLogger-Apple. Do not edit it in the mirror directly.
//
import PackageDescription

let package = Package(
    name: "MXLogger",
    platforms: [
        .iOS(.v12),
    ],
    products: [
        // Objective-C API，Swift / Objective-C 工程使用这个产品
        // Objective-C API; Swift and Objective-C apps depend on this product
        .library(name: "MXLogger", targets: ["MXLogger"]),
        // C++ 核心，仅供需要直接调用 C++ 接口的场景
        // C++ core, only for callers that need the C++ interface directly
        .library(name: "MXLoggerCore", targets: ["MXLoggerCore"]),
    ],
    targets: [
        .target(
            name: "MXLoggerCore",
            cSettings: [
                // Core 源码之间以 #include "log_enum.h" / "sink/xxx.hpp" 形式互相引用，
                // 需要把 target 根目录加入搜索路径(CMake 与 CocoaPods 默认已如此)
                // Core sources include each other as "log_enum.h" / "sink/xxx.hpp", so the
                // target root must be on the search path (CMake and CocoaPods already do this)
                .headerSearchPath("."),
                // mxlogger_build_config.h 依赖 DEBUG 判定开发期输出，与 Xcode/CocoaPods 行为对齐
                // mxlogger_build_config.h keys development-time output off DEBUG; match Xcode/CocoaPods
                .define("DEBUG", to: "1", .when(configuration: .debug)),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .target(
            name: "MXLogger",
            dependencies: ["MXLoggerCore"],
            cSettings: [
                .define("DEBUG", to: "1", .when(configuration: .debug)),
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit"),
            ]
        ),
    ],
    cxxLanguageStandard: .gnucxx17
)
