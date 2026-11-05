# Changelog

## 2.3.0

- 首次提供 HarmonyOS 原生 ArkTS SDK，复用 MXLogger Core 2.3.0。
- 支持五级日志、token 共享实例、等级和写入开关、HiLog 控制台、保留时长及大小配置。
- 支持四种分片策略、文件头、AES-CFB-128、文件列表、日志读取与清理。
- 为共享会话提供并发操作和销毁保护，支持 Worker 通过 token 写入。
- 提供 ARM64 / x86_64 原生库；ARM64 真机已完成 SDK、Demo 和十万条日志验证。
