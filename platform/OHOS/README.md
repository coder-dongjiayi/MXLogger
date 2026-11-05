# HarmonyOS 最小调用链 POC

第一阶段工程：验证 ArkTS 加载 `libmxlogger.so`，读取 Core 版本，经现有 C ABI 和
C++ 接口写入 `.mx`，关闭重开读取，以及应用进程重启后的持久化。
这是开发验证工程，尚不是可发布的 ArkTS SDK / HAR，也未接入 Flutter 鸿蒙插件。

## 工程结构

- `entry/`：Stage / ArkTS 应用，包名 `com.mxlogger.ohos.poc`。
- `build-profile.template.json5`：可提交的无签名模板；脚本首次构建生成被 Git 忽略的
  `build-profile.json5`，IDE 自动签名产生的本机证书配置保留在该本地文件中。
- `native/`：共用 Core + `Core/ffi/mxlogger_ffi.cpp` + 两个 POC Node-API 入口。
- `native/smoke.cpp`：明文和 AES 验证、相同 Core 实例检查及 JSON 报告。
- `native/runner.cpp`：仅供主机验证共享库及跨进程持久化；鸿蒙验证使用真实应用进程。

原生源文件直接引用本仓库的 `Core/`，没有复制核心实现，也没有更改已有平台代码。
POC 单独关闭 native 控制台和内部诊断打印，错误通过报告返回。

## 已验证环境

- DevEco Studio `26.0.0.865`。
- 内置 HarmonyOS SDK `26.0.0.105` / API 26，Clang 15.0.4。
- Hvigor `6.26.9`、工具链内置 Node `24.14.1`。
- ARM64 模拟器：`emulator 7.0.0.107(SP8DEVC00E999R4P11)` / API 26。
- ARM64 真机：ADY-AL00，`7.0.0.111(SP10C01E111R4P2)` / API 26，调试签名验证及安装通过。
- ARM64、x86_64 动态库及应用内打包均通过；ARM64 模拟器、真机均完成运行验证，x86_64 尚未运行。

2026-11-05 真机复验：两个不同 PID 的应用进程，明文和 AES 均从首次启动的
`previousCount=0 / readBackCount=2`，推进到第二次启动的 `2 / 4`。
导出的两类日志由现有 `MxBinaryParser` 分别解析出 4 条记录，UTF-8、字段及错误密钥检查通过。

工程声明兼容 API 12，尚未在 API 12 系统上运行，不能据此宣称最低系统已经验收。
当前 AES 在鸿蒙 ARM64 上使用既有通用 C 路径；加速汇编的选择和性能属于后续阶段。

## 可复现验证

从仓库根目录运行（Python 3.9+、主机检查另需 PATH 中有 CMake）：

```sh
# 主机独立进程检查 + 两种鸿蒙架构编译 / C ABI 导出检查
python3 scripts/verify_ohos_poc.py --host --native

# 构建包含两种架构的 ArkTS HAP
python3 scripts/verify_ohos_poc.py --hap

# 已启动的模拟器：安装本 POC，启动两次并导出沙箱日志
python3 scripts/verify_ohos_poc.py --device 127.0.0.1:5555
```

可组合为 `--host --native --device 127.0.0.1:5555`。
工具默认位于 `/Applications/DevEco-Studio.app/Contents`，其他位置使用 `--deveco` 指定。
脚本使用 IDE 自带的 Hvigor 和 OHPM；只安装工程内的本地类型声明依赖。
生成的工具路径、缓存和依赖链接均在忽略目录内，不修改系统 PATH。

脚本只对识别为模拟器的设备尝试安装 unsigned HAP。真机先在 IDE 配置本工程的自动调试签名，
再运行 `--device 真机序列号`；也可以用已签名的 POC Debug 包：

```sh
python3 scripts/verify_ohos_poc.py --device 真机序列号 --signed-hap /绝对路径/entry-default-signed.hap
```

脚本检查应用包名、Debug 标记，并用 SDK 的 `hap-sign-tool verify-app` 验证真机用包的签名，
之后才安装。它不会关闭系统签名校验，也不会修改设备权限。
两次运行仅停止本 POC 应用，保留日志。签名密码、证书和 profile 不应提交到 Git。

验证报告位于 `build/ohos-poc/`：

- `host-report.json`：主机明文 / AES 的两个独立进程报告。
- `arm64-v8a-exports.txt`、`x86_64-exports.txt`：共享 C ABI 导出检查。
- `hap-build.log`、`entry-default-unsigned.hap`：构建日志与安装包。
- `devices/<target>/<run>/device-hilog.txt`、`device-report.json`：两个应用进程的独立报告。
- `devices/<target>/<run>/logs/`：该次验证导出的 `.mx` 文件。
- `device-report-<target>.json`：该设备最近一次成功报告，包含系统、架构、API、包摘要及导出目录。

模拟器和真机各自保存证据，不会相互覆盖。旧版脚本生成的 `device-report.json` 仍可传给解析验证工具。

每次启动分别给明文、加密 logger 写两条日志：一条走 FFI，一条走 C++。
报告中的 `sharedCore` 通过 FFI token 回查 C++ 实例并核对指针身份；
第二次启动必须具有不同 PID，且 `previousCount` 等于第一次的 `readBackCount`。
测试同时检查关闭重开后保留旧记录、两条新记录都精确出现一次。

## 使用现有解析器验证

先确保解析器项目已经完成 `flutter pub get`，然后从仓库根目录运行：

```sh
dart --packages=mxlogger_analyzer/mxlogger_analyzer_lib/.dart_tool/package_config.json \
  scripts/verify_ohos_logs.dart build/ohos-poc/device-report-127.0.0.1_5555.json
```

该工具直接调用现有 `MxBinaryParser`，根据本次设备报告找到导出文件，检查实际记录数、
UTF-8、等级、线程和时间戳、FFI / native 记录比例，以及错误密钥不能成功解密。
使用的固定 key `poc-test-key-1234` 和 IV `poc-test-iv--1234` 仅供 POC 测试。
也可以把导出的文件手动导入现有桌面 / Chrome 解析器。

## 在 IDE 中运行

先运行一次 `--hap`，或复制 `build-profile.template.json5` 为 `build-profile.json5`。
随后打开 `platform/OHOS`，同步本地依赖后选择 `entry` 和设备运行。
页面启动时自动执行明文与 AES 检查，可点“再次验证”追加检查。
关闭后重新启动应用，报告应显示之前写入的记录仍然存在。

## 后续工作

此 POC 的同步桥接仅用于小规模验证。完整公开 API、HiLog 策略、并发销毁保护、
多线程 / isolate、日志清理、HAR / OHPM 发布和 Flutter 鸿蒙接入尚需后续实现与验收。
