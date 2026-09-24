// swift-tools-version: 5.9
// flutter_mxlogger 插件的 SwiftPM 清单(iOS)。宿主 App 开启 Flutter 的 Swift Package Manager 支持
// (flutter config --enable-swift-package-manager)时由 flutter_tools 自动接入；否则仍走 podspec。
// 源码与 CocoaPods 共用 Sources/flutter_mxlogger 目录。
// SwiftPM manifest for the flutter_mxlogger plugin (iOS). Picked up by flutter_tools when the host
// app has Flutter's Swift Package Manager support enabled; the podspec is used otherwise.
// Sources under Sources/flutter_mxlogger are shared with CocoaPods.

import PackageDescription

let package = Package(
    name: "flutter_mxlogger",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "flutter-mxlogger", targets: ["flutter_mxlogger"]),
    ],
    dependencies: [
        // Flutter.framework，由 flutter_tools 生成到插件包旁边 / generated next to this package by flutter_tools
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // 原生 MXLogger(OC + C++ Core)，与 podspec 中 MXLogger 2.1.0 对应
        // Native MXLogger (ObjC + C++ core), matches `MXLogger 2.1.0` in the podspec
        .package(url: "https://github.com/coder-dongjiayi/MXLogger-SwiftPM.git", exact: "2.1.0"),
    ],
    targets: [
        .target(
            name: "flutter_mxlogger",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "MXLogger", package: "MXLogger-SwiftPM"),
            ],
            cSettings: [
                .headerSearchPath("include/flutter_mxlogger"),
            ]
        ),
    ]
)
