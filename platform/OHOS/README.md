# MXLogger HarmonyOS SDK

提供 ArkTS SDK、Release HAR、原生 Demo，以及独立 HAR 消费工程的构建与真机验证脚本。
开发工程默认包版本 `0.1.0`，发布包版本由打包脚本参数指定；Core 版本由 `MXLogger.coreVersion()` 返回（本次为 `2.3.0`）。
OHPM 包名为 `@djy/mxlogger`，发布版本为 `2.3.1`，通过 OHPM 中心仓安装。
当前为原生 ArkTS 接入，Flutter 鸿蒙绑定尚未完成。

## 通过 OHPM 安装

在业务模块目录（例如 `entry/`）执行：

```sh
ohpm install @djy/mxlogger@2.3.1
```

或在模块的 `oh-package.json5` 添加以下依赖，再执行 `ohpm install`：

```json
{
  "dependencies": {
    "@djy/mxlogger": "2.3.1"
  }
}
```

安装后使用 `import { MXLogger } from '@djy/mxlogger'`。
声明最低 API 12；已完成 API 26 / ARM64 真机验证，x86_64 已构建但未运行，完整环境见文末。

## 原生 Demo

用 DevEco Studio 打开 `platform/OHOS`，选择 `entry` 运行。桌面名称为 **MXLogger Demo**，
AppIcon 直接复用 iOS Demo 的 `AppIcon.appiconset/icon-1024.png`；欢迎页 Logo 也与 iOS / Android 相同。
正常启动进入欢迎页，点击「进入演示」打开功能面板。右上角可切换中文 / English。

默认参数与其他平台示例一致：namespace 为 `com.djy.mxlogger`，按小时分片，AES-CFB-128，
key 为 `abcdefgabcdefgob`，IV 为 `abcdefgabcdefgcc`，保留 7 天 / 10 MB，Debug 等级，HiLog 默认关闭。
密钥仅供演示。默认数据目录为 `context.filesDir/mxlogger_demo/<policy>_<aes|plain>/`，
分开保存不同分片策略、明文和密文，避免切换参数时混用文件。

| 页面 / 操作 | 对应公开 API |
| --- | --- |
| 五级写入、模拟网络请求、自定义 name / tag / message | `debug/info/warn/error/fatal/log` |
| token 写入、关联共享实例 | `logWithToken`、`fromLoggerToken` |
| 日志等级、写入开关、控制台开关 | `setLevel/level`、`setEnable/enable`、`setConsoleEnable/consoleEnable` |
| 保留时长、大小上限 | `setMaxDiskAge/maxDiskAge`、`setMaxDiskSize/maxDiskSize` |
| 初始化 / 重建：目录、namespace、fileName、header、四种策略、AES 开关 | `initialize`、`initializeWithDirectory`、`MXLoggerOptions` |
| 顶部状态、实例信息、复制 token / 路径 | `state`、`isValid`、`coreVersion`、`logSize`、`loggerToken`、`diskCachePath`、`errorDesc` |
| 文件列表及大小 / 创建 / 修改时间、日志详情 | `logFiles`、`readLogFile` |
| flush、按配置清理、清理历史 / 全部非活跃文件 | `flush`、`removeExpireData`、`removeBeforeAllData`、`removeAll` |
| 销毁、重新初始化 | `destroy`、`isValid` |

文件详情展示等级、时间、name、tag、完整消息入口、主线程 / Worker 和 threadId；支持搜索和等级筛选，
每页 100 条，点击记录可查看和复制完整 JSON。清理和销毁均有应用内确认提示。
等级过滤或禁用写入时，界面明确显示记录未保存；销毁后可从「初始化参数 / 重建」恢复。

性能演示提供单 Worker 写入 100,000 条，以及 4 个 Worker 各写入 1,000 条。
批量基准与 iOS / Android / macOS / Flutter 使用相同的六位序号消息
`[000001] This is a benchmark loooooooooooooooooooooooooooooog`，序号从 `000001` 到 `100000`，
每条 message 固定 61 个 UTF-8 字节，`name=benchmark`、`tag=perf`，调用 Info 写入。
61 B 仅指 message；在该基准的 Info / 后台线程元数据下，Core 序列化为 152 B，
加上每条记录的 4 B 长度字段共 156 B。AES-CFB 不增加记录长度。
100,000 条有效记录占 15,600,000 B，不包含文件头；文件物理大小还受 mmap 预分配影响。
导出 Demo 日志后可核对最近一次完整基准的消息、顺序、元数据及逐条编码大小：

```sh
dart --packages=mxlogger_analyzer/mxlogger_analyzer_lib/.dart_tool/package_config.json \
  scripts/verify_ohos_benchmark.dart EXPORTED_DEMO_DIRECTORY --aes
```

明文文件省略 `--aes`。传入同一个 Demo namespace 的导出目录，避免混入其他密钥的文件。
这些操作复用主线程初始化的 token，界面等待全部 Worker 结束后才允许重建或销毁；
显示的总耗时包含 Worker 启动、线程间传递及 flush，不能当作 Core 的独立吞吐基准。
运行时需要开启写入并选择 Debug / Info 等级，期间临时关闭控制台，结束后恢复。

自动验收保留为「开发验证」入口，也可通过启动参数 `--ps mxloggerPage verification` 直接打开；
它使用独立的测试 namespace。构建 / 安装与验收命令见后文。安装后可执行实际 UI 回归：

```sh
python3 scripts/verify_ohos_demo.py --device DEVICE_ID
```

该脚本操作 Demo 的真实控件，覆盖中英文、五级与自定义写入、过滤与 enable、配置、
两种 Worker 写入、文件及记录分页、清理、销毁重建和明文 / AES 初始化。
步骤报告、布局及截图输出到 `build/ohos-sdk/demo-ui/<run>/`，测试结束恢复按小时 / AES 示例。

## 使用示例

业务工程需要 ArkTS 工具链，不需要 MXLogger Core 源码或 CMake 配置。
HAR 自带 ARM64 / x86_64 的 `libmxlogger.so`；当前 DevEco 默认生成字节码 HAR，含公开类型声明与 `.abc`。

```typescript
import { MXLogger, MXLogLevel, MXStoragePolicy } from '@djy/mxlogger';

const context = this.getUIContext().getHostContext();
if (!context) { throw new Error('Context unavailable'); }
const logger = MXLogger.initialize(context, {
  nameSpace: 'com.example.app',
  storagePolicy: MXStoragePolicy.Daily,
  fileHeader: '{"app_version":"1.0.0"}'
});
logger.setMaxDiskAge(7 * 24 * 60 * 60);
logger.setMaxDiskSize(20 * 1024 * 1024);
logger.setLevel(MXLogLevel.Debug);
logger.info('开始校验 token', { name: 'login', tag: 'login,service' });
logger.error('请求失败', { name: 'network', tag: 'network' });

const token = logger.loggerToken;
MXLogger.logWithToken(token, MXLogLevel.Info, '子模块日志');
```

默认基础目录为 `context.filesDir/com.mxlog.LoggerCache`，Core 追加 namespace。
可通过 `options.directory` 自定义，或使用不需要 Context 的 `initializeWithDirectory(directory, options)`。
目录必须是绝对路径；namespace 和 fileName 必须是单个非空路径分量。

## API

| 类别 | 接口 |
| --- | --- |
| 初始化 | `initialize`、`initializeWithDirectory`、`fromLoggerToken`、`coreVersion` |
| 写入 | `log`、`debug/info/warn/error/fatal`、静态 `logWithToken` |
| 状态 | `state`、`isValid`、`loggerToken`、`diskCachePath`、`errorDesc` |
| 配置 | `setLevel`、`setEnable`、`setConsoleEnable`、`setMaxDiskAge`、`setMaxDiskSize` |
| 配置读取 | `level`、`enable`、`consoleEnable`、`maxDiskAge`、`maxDiskSize`、`logSize` |
| 文件 | `logFiles`、`readLogFile(filename)` |
| 管理 | `flush`、`removeExpireData`、`removeBeforeAllData`、`removeAll`、`destroy` |

- 等级：`Debug=0`、`Info=1`、`Warn=2`、`Error=3`、`Fatal=4`。
- 策略：`Daily`、`Hourly`、`Weekly`、`Monthly`。
- `log` 成功返回 `0`；被等级过滤或禁用时也返回 `0`。ArkTS 调用失败会抛出带 code 的 Error。
- 错误 code：`MXLOGGER_ARGUMENT`、`MXLOGGER_CLOSED`、`MXLOGGER_CONFLICT`、`MXLOGGER_IO`。
- 大小为字节，保留时长为秒；`0` 表示不限制。支持非负 JS 安全整数，原生边界额外检查。
- `MXLogFile` 提供 `name/size/lastTimeStamp/createTimeStamp`，时间戳单位为秒；鸿蒙创建时间以 mtime 近似。
- `MXLogRecord.timestamp` 为微秒；`isMainThread` 表示 OS 主线程，Worker 写入会标记为 false。
- `readLogFile` 使用该 logger 的加密参数，同步返回记录，也包含原有 fileHeader 记录。
- `flush` 请求映射数据写回，沿用 Core 的异步 flush 语义，不是断电持久化屏障。
- 三个清理接口都保留当前正在使用的文件；`removeExpireData` 同时按 age / size 策略清理。

AES 示例：在初始化参数中传 `cryptKey`、`iv`。沿用 AES-CFB-128：推荐各 16 个 UTF-8 字节，
较长截断、较短补零；IV 缺省时使用 key。重开现有目录时应使用一致的加密参数。

## 共享实例与生命周期

同一个规范化 directory + namespace 共用一个会话，但每个包装对象独立持有 native handle。
重复初始化不会重置运行时配置；初始化参数与存活会话冲突时抛出 `MXLOGGER_CONFLICT`。

配置、写入、查询、清理和 flush 都在会话锁内执行。销毁等待在途操作退出，随后使所有别名失效；
旧对象继续写入会安全失败。重新初始化创建新一代会话，旧对象再次 destroy 不会影响新会话。
不同 logger 具有独立操作锁；token 查询和包装对象管理使用独立注册表锁。

`destroy()` 为共享会话级操作，可重复调用。GC 仅释放当前包装对象，不自动销毁进程共享会话。
使用 loggerToken 的 Worker 可以调用 `fromLoggerToken`；结束 Worker 不会关闭 UI 侧 logger。
当前只承诺同进程共享；多进程共写尚未验收。

## 控制台与 C ABI

发行 HAR 保留 HiLog 控制台能力，默认关闭，`setConsoleEnable(true)` 后按等级输出。
Core 的 stdout / 内部诊断打印在该构建中关闭，错误通过返回值、Error 和 errorDesc 保留。

鸿蒙适配层继续实现 `Core/ffi/mxlogger_ffi.h` 中的公共 C ABI，并共用其内存分配辅助代码。
Core 与其他平台封装未改动。鸿蒙句柄为不透明包装对象，不能转换成 `mx_logger*`。
销毁会话后句柄仍可安全判定失效；调用方最终需调用 `flutter_mxlogger_release_handle`，并永久丢弃指针。
ArkTS 的 Native 对象 finalizer 会自动 release。后续 Flutter 鸿蒙绑定需要遵守同一约定。

字符串及数组继续使用成对的 `free_string/free_logfiles/free_logmsg` 释放。
新增鸿蒙扩展声明见 `mxlogger/src/main/cpp/mxlogger_ohos.h`。
独立路径的 legacy `select_logmsg` 不持有会话锁；并发读取活跃 logger 请使用 SDK 的 `readLogFile`。

## 构建与验证

### 生成 OHPM 发布 HAR

从仓库根目录执行，或在任意目录用脚本的绝对路径执行：

```sh
sh scripts/ohos_release.sh 2.3.1
```

需要 Python 3 和已安装 SDK 的 DevEco Studio。默认使用 macOS 的
`/Applications/DevEco-Studio.app/Contents`，其他安装路径可指定：

```sh
DEVECO_HOME="/path/to/DevEco-Studio.app/Contents" sh scripts/ohos_release.sh 2.3.1
```

脚本将版本号写入隔离构建副本的 `oh-package.json5`，重新编译 Release HAR，
检查包内版本、作者、关键词、项目主页、公开 API、ARM64 / x86_64 动态库及 C ABI 导出，随后运行 `ohpm prepublish` 本地校验。
发布包包含模块的 README、CHANGELOG、仓库根目录的完整许可证及 `example/` 示例源码和运行说明；
脚本同时核对包内示例与源码一致，避免只在仓库里添加目录而没有实际发布。
不会修改源码版本、Core 版本、本机签名配置或执行上传。

产物目录为 `build/ohos-release/2.3.1/`：

- `mxlogger-2.3.1.har`：用于发布的 SDK。
- `mxlogger-2.3.1.har.sha256`、`release-report.json`：摘要及版本 / 架构 / 校验结果。
- `build.log`、`prepublish.log`、`har-contents.txt`、`har-libs/`：构建和包内容证据。

配置 OHPM 账号、`@djy` 组织发布权限及认证后，可手动发布：

```sh
ohpm publish build/ohos-release/2.3.1/mxlogger-2.3.1.har
```

`prepublish` 仅验证包内容，不验证组织权限或发布认证，也不替代中心仓审核。
发新版本前应更新模块的 `CHANGELOG.md`。

### 开发验收

从仓库根目录执行：

```sh
# ASan 主机合同测试 + Release HAR + 独立消费者构建
python3 scripts/verify_ohos_sdk.py --host

# 上述构建，并在指定设备安装独立消费者，启动两个进程进行合同验证
python3 scripts/verify_ohos_sdk.py --device DEVICE_ID
```

工具默认位于 `/Applications/DevEco-Studio.app/Contents`，可通过 `--deveco` 修改。
脚本首次构建从 `build-profile.template.json5` 生成被 Git 忽略的 `build-profile.json5`。
真机需先在 IDE 配置自动调试签名，并为 default product 选择 signingConfig。
证书、密码与本机配置保留在忽略目录，脚本使用 SDK verifier 校验签名后才安装真机。

独立消费者位于 `build/ohos-sdk/consumer-*`：只有 Demo 和本地 HAR，没有 SDK 模块 / Core 源码依赖。
脚本检查消费者没有生成 CMakeCache / C++ 对象，HAP 中每种架构只有一个 `libmxlogger.so`，
并对 HAR 内两种架构的共用 C ABI 和鸿蒙扩展做导出符号检查。

真机合同覆盖：五级日志、等级与 enable、共享配置、64 位设置、header、token、错误参数、
三种清理与保留活跃文件、别名失效、重新初始化、四种存储策略及 AES、Worker 写入与线程标记。
随后执行明文与加密的跨进程重启读取。主机 ASan 检查另外覆盖 10,000 次并发写入与销毁竞争。
macOS ASan 不支持 LSan，本次不宣称做了 LeakSanitizer 验证。

产物及证据位于 `build/ohos-sdk/`：

- `mxlogger-0.1.0.har`：Release SDK。
- `mxlogger-demo.hap`：仅依赖 HAR 构建的原生 Demo（真机安装需匹配本机签名设备）。
- `har-contents.txt`、`har-libs/<abi>/exports.txt`：包内容及动态导出符号。
- `consumer-report.json`：HAR 摘要及独立消费者的 HAP 路径。
- `host-tests.log`：AddressSanitizer 合同测试。
- `devices/<target>/<run>/device-report.json`、`device-hilog.txt`、`logs/`：设备合同及导出日志。
- `device-report-<target>.json`：该设备最近一次成功报告。

确保解析器项目已经运行 `flutter pub get` 后，可直接用现有解析器验证设备导出文件：

```sh
dart --packages=mxlogger_analyzer/mxlogger_analyzer_lib/.dart_tool/package_config.json \
  scripts/verify_ohos_logs.dart build/ohos-sdk/device-report-DEVICE_ID.json
```

## 验证环境与边界

2026-11-05：DevEco Studio `26.0.0.865`，HarmonyOS SDK `26.0.0.105` / API 26，
Clang 15.0.4，Hvigor `6.26.9`，Node `24.14.1`。

ARM64 真机 ADY-AL00 / `7.0.0.111(SP10C01E111R4P2)` 完成独立 HAR 消费者验收。
ARM64、x86_64 均编译并打包；x86_64 尚未运行。工程声明最低 API 12，尚未在 API 12 设备执行。
AES 在鸿蒙 ARM64 使用原有通用 C 路径，加速汇编与性能基准不在本阶段验收范围。

第一阶段的独立 C++ 探针保留在 `native/`，可用 `scripts/verify_ohos_poc.py --host --native`
重跑原始构建检查。正式 SDK 验收使用 `verify_ohos_sdk.py`。
