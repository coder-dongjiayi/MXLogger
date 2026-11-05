# MXLogger HarmonyOS SDK

本模块提供 ArkTS API 和共用 `libmxlogger.so`，通过本地 HAR 接入。
完整接入、生命周期及验收说明见上一级 `README.md`。
包版本为 `0.1.0`，Core 版本由 `MXLogger.coreVersion()` 在运行时读取。

本地调试依赖：`"@mxlogger/mxlogger": "file:../mxlogger"`。
独立工程只需要生成的 HAR，不需要本仓库的 Core 源码或 C++ 编译配置。

原生桥接层继续导出 `Core/ffi/mxlogger_ffi.h` 的共用 C ABI，增加鸿蒙会话保护及
`flutter_mxlogger_release_handle`。句柄为不透明包装对象；销毁使同会话所有对象失效，
release/GC 仅释放单个包装对象。此约定供后续 Flutter 鸿蒙 FFI 绑定使用。
