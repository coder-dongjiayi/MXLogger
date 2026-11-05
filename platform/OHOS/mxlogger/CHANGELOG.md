# Changelog

## 2.3.1

- 调整 OHPM 组织名，包名为 `@djy/mxlogger`。
- 补充 OHPM 包主页 `homepage`。
- 发布包内提供 `example/`：可直接放入 Empty Ability 工程运行的 ArkTS 示例及接入说明。
- 打包时检查 homepage、示例源码和文档是否完整包含在最终 HAR 中。

## 2.3.0

- 首次提供 HarmonyOS 原生 ArkTS SDK，复用 MXLogger Core 2.3.0。
- 支持五级日志、token 共享实例、等级和写入开关、HiLog 控制台、保留时长及大小配置。
- 支持四种分片策略、文件头、AES-CFB-128、文件列表、日志读取与清理。
- 为共享会话提供并发操作和销毁保护，支持 Worker 通过 token 写入。
- 提供 ARM64 / x86_64 原生库；ARM64 真机已完成 SDK、Demo 和十万条日志验证。
