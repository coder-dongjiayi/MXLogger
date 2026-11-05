# MXLogger HarmonyOS SDK

基于 mmap、FlatBuffers 和 AES-CFB-128 的原生日志 SDK。提供 ArkTS API，HAR 内含
ARM64 / x86_64 的 `libmxlogger.so`；接入方不需要 MXLogger Core 源码或 CMake 配置。

源码：[coder-dongjiayi/MXLogger](https://github.com/coder-dongjiayi/MXLogger)。
包版本见 `oh-package.json5`，Core 版本通过 `MXLogger.coreVersion()` 获取。

## 示例

发布包内附带 [`example/`](./example/README.md)，包含可直接放入 Empty Ability 工程运行的 ArkUI 页面，
展示初始化、五级日志、token 共享、配置、文件读取与销毁。
完整功能面板、文件查看器与 Worker 演示见仓库的[原生 Demo](https://github.com/coder-dongjiayi/MXLogger/tree/main/platform/OHOS)。

## 安装

在业务模块目录（例如 `entry/`）安装 OHPM 版本：

```sh
ohpm install @djy/mxlogger@2.3.1
```

也可以在业务模块的 `oh-package.json5` 中声明中心仓依赖，再执行 `ohpm install`：

```json
{
  "dependencies": {
    "@djy/mxlogger": "2.3.1"
  }
}
```

## 使用

```typescript
import { MXLogger, MXLogLevel, MXStoragePolicy } from '@djy/mxlogger';

const context = this.getUIContext().getHostContext();
if (!context) { throw new Error('Context unavailable'); }
const logger = MXLogger.initialize(context, {
  nameSpace: 'com.example.app',
  storagePolicy: MXStoragePolicy.Hourly,
  fileHeader: '{"appVersion":"1.0.0"}'
});
logger.setMaxDiskAge(7 * 24 * 60 * 60);
logger.setMaxDiskSize(10 * 1024 * 1024);
logger.setLevel(MXLogLevel.Debug);
logger.info('HarmonyOS 中文日志 ✅', { name: 'network', tag: 'request' });

const alias = MXLogger.fromLoggerToken(logger.loggerToken);
alias.warn('共享实例写入');
MXLogger.logWithToken(logger.loggerToken, MXLogLevel.Error, '静态 token 写入');

for (const file of logger.logFiles) {
  const records = logger.readLogFile(file.name);
  console.info(file.name + ': ' + records.length + ' records');
}
logger.flush();
// 在业务生命周期结束、且无需继续使用共享实例时执行：
logger.destroy();
```

默认基础目录为 `context.filesDir/com.mxlog.LoggerCache`，Core 追加 namespace。
可传 `options.directory`，或使用 `initializeWithDirectory(directory, options)` 指定绝对路径。
初始化参数还支持 `fileName`、`cryptKey`、`iv`。AES-CFB-128 推荐 key / IV 各 16 个 UTF-8 字节，
重开现有加密目录时需要保持一致。四种策略为 `Daily / Hourly / Weekly / Monthly`。

## API

| 类别 | 接口 |
| --- | --- |
| 初始化 | `initialize`、`initializeWithDirectory`、`fromLoggerToken`、`coreVersion` |
| 写入 | `log`、`debug/info/warn/error/fatal`、静态 `logWithToken` |
| 配置 | `setLevel`、`setEnable`、`setConsoleEnable`、`setMaxDiskAge`、`setMaxDiskSize` |
| 状态 | `state`、`isValid`、`loggerToken`、`diskCachePath`、`errorDesc`、`logSize` |
| 配置读取 | `level`、`enable`、`consoleEnable`、`maxDiskAge`、`maxDiskSize` |
| 文件 | `logFiles`、`readLogFile` |
| 管理 | `flush`、`removeExpireData`、`removeBeforeAllData`、`removeAll`、`destroy` |

大小单位为字节，保留时长单位为秒，`0` 表示不限制。日志等级从 Debug=0 到 Fatal=4。
HiLog 默认关闭，`setConsoleEnable(true)` 后按当前等级输出。
被等级过滤或禁用时写入返回 `0`，记录不会保存；失败会抛出带 code 的 Error：
`MXLOGGER_ARGUMENT / MXLOGGER_CLOSED / MXLOGGER_CONFLICT / MXLOGGER_IO`。

`MXLogFile` 提供文件名、大小和秒级创建 / 修改时间；鸿蒙创建时间以 mtime 近似。
`MXLogRecord` 包含 name、tag、msg、level、微秒 timestamp、threadId 和 isMainThread。
三个清理接口均保留当前活跃文件。`flush` 沿用 Core 的异步映射刷回语义。

## 生命周期与 Worker

同一 directory + namespace 共用会话；配置与读写在会话锁内执行。Worker 可通过 token 获取共享实例。
`destroy()` 可重复调用，但会使该会话的所有别名失效；重新初始化产生新会话，旧对象不会销毁新会话。
GC 只释放当前包装对象，不关闭进程共享会话；不再使用时应显式 destroy。
当前只承诺同进程共享，多进程共写尚未验收。

原生库保留公共 C ABI。鸿蒙句柄是不透明包装对象；C / FFI 调用方销毁会话后还需调用
`flutter_mxlogger_release_handle` 并丢弃指针，ArkTS 包装对象由 finalizer 自动 release。

## 支持范围

声明最低 API 12；当前完成 API 26 / ARM64 真机的 SDK、Worker、重启读取及十万条 AES 日志验证。
x86_64 已编译打包，尚未执行设备验收。AES 使用通用 C 实现。

[完整接入说明、Demo 和验证脚本](https://github.com/coder-dongjiayi/MXLogger/tree/main/platform/OHOS)
