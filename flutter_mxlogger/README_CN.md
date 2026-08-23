# flutter_mxlogger

English documentation is available [here](./README.md).

MXLogger 是基于 mmap 内存映射机制的跨平台日志库，支持 AES CFB 128 位加密。核心用 C/C++ 实现，序列化使用 Google FlatBuffers，Flutter 端通过 `dart:ffi` 直接调用，性能几乎与原生一致。

更多说明见 [MXLogger 主仓库](https://github.com/coder-dongjiayi/MXLogger)。

- **当前版本**：2.0.0
- **环境要求**：Dart SDK `>=2.18.0 <4.0.0`、Flutter `>=3.3.0`
- **平台支持**：iOS（>= 9.0）、Android（minSdk 21）

## 安装

```yaml
dependencies:
  flutter_mxlogger: ^2.0.0
```

原生依赖会自动引入，无需手动配置：

- iOS：CocoaPods 依赖 `MXLogger 2.0.0` → `MXLoggerCore 2.0.0`
- Android：Gradle 依赖 `io.github.coder-dongjiayi:mxlogger:2.0.0`

## 快速开始

```dart
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

final logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyy_MM_dd_HH,
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 字节
  iv: "bccuioqbsdguijiv",         // 不传则与 cryptKey 相同
);

logger.setMaxDiskAge(60 * 60 * 24 * 7); // 最多保留 7 天
logger.setMaxDiskSize(1024 * 1024 * 10); // 最多占用 10MB
logger.setLevel(0);                      // 0:debug 以上全部写文件

logger.debug("this is debug message", name: "mxlogger", tag: "net,response");
logger.info("this is info message", name: "mxlogger", tag: "tag1,tag2");
logger.warn("this is warn message");
logger.error("this is error message");
logger.fatal("this is fatal message");
```

---

# 一、各平台运行机制

## 1.1 整体结构

```
┌──────────────────────────────────────────────────────────────┐
│  Dart 层    lib/src/flutter_mxlogger.dart                    │
│  · MethodChannel("flutter_mxlogger") — 仅用于取默认目录      │
│  · dart:ffi — 所有读写操作，零 Channel 开销                  │
│  · WidgetsBindingObserver — 进后台触发过期清理               │
└──────────────┬───────────────────────────┬───────────────────┘
               │ ffi lookup                │ ffi lookup
               │ (符号前缀 flutter_mxlogger_)                  │
┌──────────────▼──────────────┐ ┌──────────▼───────────────────┐
│ iOS  flutter-bridge.mm      │ │ Android flutter-bridge.cpp   │
│ 桥接 Objective-C MXLogger   │ │ 直接桥接 C++ mx_logger       │
└──────────────┬──────────────┘ └──────────┬───────────────────┘
               │                           │
        ┌──────▼───────────────────────────▼──────┐
        │  Core (C/C++)：mmap + AES-CFB-128       │
        │  + FlatBuffers 序列化                   │
        └─────────────────────────────────────────┘
```

关键点：**日志写入路径上没有 MethodChannel**。`log()` 从 Dart 到磁盘全程是 FFI 同步调用，不经过消息队列、不产生 codec 编解码，也不需要等待平台线程调度。

---

# 二、Dart API

## 2.1 初始化

### `MXLogger.initialize`（推荐）

```dart
static Future<MXLogger> initialize({
  required String nameSpace,
  String? directory,
  bool consoleEnable = false,
  MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyy_MM_dd,
  String? fileName,
  String? fileHeader,
  String? cryptKey,
  String? iv,
})
```

| 参数 | 说明 |
|---|---|
| `nameSpace` | 日志命名空间，建议用域名反转保证唯一。最终目录为 `directory/nameSpace` |
| `directory` | 自定义目录。不传则通过 MethodChannel 取平台默认路径：iOS `<Library>/com.mxlog.LoggerCache`、Android `<filesDir>/com.mxlog.LoggerCache` |
| `consoleEnable` | 是否开启控制台打印，仅 debug 构建有效 |
| `storagePolicy` | 文件切分策略，见 2.2 |
| `fileName` | 自定义文件名，默认 `mxlog` |
| `fileHeader` | 文件头信息，文件**创建时**写入一次。适合放 App 版本、平台、设备型号等上下文 |
| `cryptKey` | AES 密钥。**16 字节：超长截断，不足补 0**。不传则不加密 |
| `iv` | 初始化向量，规则同 `cryptKey`。不传则与 `cryptKey` 相同 |

> ⚠️ `cryptKey` / `iv` 不足 16 字节时补 0 的行为在 v2.0.0 才修复完整。用短 key 写出的旧日志解析器可能读不出来，建议直接用满 16 字节。

### 同步构造函数

```dart
MXLogger({required String nameSpace, required String directory, ...})
```

`directory` 必传，不走 MethodChannel，可同步调用。

**初始化失败时不会抛异常**：native 返回空句柄（比如目录创建不了），实例会被自动置为 `enable == false`，后续所有调用安全短路，不会把空指针带进 native。可以通过 `logger.enable` 判断。

## 2.2 存储策略 `MXStoragePolicyType`

| 枚举值 | 切分粒度 | 文件名示例 |
|---|---|---|
| `yyyy_MM_dd`（默认） | 按天 | `2023-01-11_mxlog.mx` |
| `yyyy_MM_dd_HH` | 按小时 | `2023-01-11-15_mxlog.mx` |
| `yyyy_ww` | 按周 | `2023-01-02w_mxlog.mx`（`02w` = 当年第 2 周） |
| `yyyy_MM` | 按月 | `2023-01_mxlog.mx` |

## 2.3 写日志

### 实例方法

```dart
int debug(String msg, {String? name, String? tag});
int info (String msg, {String? name, String? tag});
int warn (String msg, {String? name, String? tag});
int error(String msg, {String? name, String? tag});
int fatal(String msg, {String? name, String? tag});

int log(int lvl, String msg, {String? name, String? tag});
```

- `lvl`：`0` debug、`1` info、`2` warn、`3` error、`4` fatal
- `name`：日志名称，通常放模块名
- `tag`：标记，多个用逗号分隔（`"net,response"`），解析器里可按 tag 过滤
- `msg` 若是合法 JSON，控制台会自动格式化缩进输出

**返回值**：

| 值 | 含义 |
|---|---|
| `0` | 成功 |
| `-1` | 文件扩容失败 |
| `-2` | 解除映射失败 |
| `-3` | mmap 映射失败 |

### 类方法（组件化场景）

大型 App 拆成多个模块时，子模块往往不方便持有 logger 对象。这时只需传递 `loggerKey` 字符串：

```dart
// 主工程
final key = logger.loggerKey;   // 保存起来，或注册到全局服务

// 子模块，不依赖 logger 实例
MXLogger.infoLog(key, "module message", name: "user_module", tag: "login");
```

```dart
static void logLoggerKey(String? loggerKey, int lvl, String msg, {String? name, String? tag});
static void debugLog(String? loggerKey, String msg, {String? name, String? tag});
static void infoLog (String? loggerKey, String msg, {String? name, String? tag});
static void warnLog (String? loggerKey, String msg, {String? name, String? tag});
static void errorLog(String? loggerKey, String msg, {String? name, String? tag});
static void fatalLog(String? loggerKey, String msg, {String? name, String? tag});
```

同一个 `loggerKey` 在原生侧也能用——Android 走 `FlutterMxloggerPlugin.info(...)`，iOS 走 `[FlutterMxloggerPlugin info:...]`，写进的是同一份文件。

## 2.4 开关与等级

```dart
void setLevel(int lvl);        // 只有 >= lvl 的日志写入文件
void setEnable(bool enable);   // 总开关，false 时完全不写
void setConsoleEnable(bool enable);
void shouldRemoveExpiredDataWhenEnterBackground(bool should); // 默认 true
```

- `setLevel(2)` 表示 warn 及以上才落盘，debug/info 被丢弃。**注意这个开关不影响控制台**，控制台仍会打印全部等级。
- `setConsoleEnable` 写的是一个**静态字段**，对所有 logger 实例全局生效；新建 logger 时传入的 `consoleEnable` 同样会覆盖全局值。

> 🔁 从 1.x 迁移：旧版的 `setFileLevel(int)` 已更名为 `setLevel(int)`，语义不变。

## 2.5 磁盘管理

```dart
void setMaxDiskAge(int seconds);  // 默认 0 = 不限制
void setMaxDiskSize(int bytes);   // 默认 0 = 不限制

void removeExpireData();      // 按上面两个阈值清理
void removeBeforeAllData();   // 删除除当前写入文件外的所有日志
void removeAll();             // 删除所有日志文件
```

`removeExpireData()` 的清理顺序：先按最后修改时间删掉超过 `maxDiskAge` 的文件；若总大小仍超过 `maxDiskSize`，再从最旧的开始继续删。**当前正在写入的文件永远不会被删除。**

App 进入后台时会自动调用一次，可通过 `shouldRemoveExpiredDataWhenEnterBackground(false)` 关闭。

## 2.6 状态查询

| 成员 | 类型 | 说明 |
|---|---|---|
| `enable` | `bool` | 日志写入是否可用 |
| `consoleEnable` | `bool` | 控制台开关（全局） |
| `loggerKey` | `String?` | 底层唯一标识，用于组件化传递 |
| `diskcachePath` | `String` | 日志目录（`directory` + `nameSpace`） |
| `diskcacheErrorPath` | `String` | 错误记录文件路径，即 `diskcachePath/error.txt` |
| `logSize` | `int` | 已存日志总字节数 |
| `logFiles` | `List<MXFileEntity>` | 日志文件列表 |
| `errorDesc` | `String?` | 最近一次写入失败的描述，无错误返回 `null` |
| `cryptKey` / `iv` | `String?` | 初始化时传入的加密参数 |

### `MXFileEntity`

```dart
class MXFileEntity {
  String? name;          // 文件名
  int size;              // 字节数
  int createTimeStamp;   // 创建时间戳（秒）
  int lastTimeStamp;     // 最后修改时间戳（秒）

  DateTime get createTime;
  DateTime get lastTime;
}
```

## 2.7 写入失败的兜底记录

`log()` 返回非 0 时，日志本身没写进去，此时可以把失败信息记到一个独立的纯文本文件里，方便事后排查：

```dart
final code = logger.error("something went wrong");
if (code != 0) {
  logger.writeFail(
    code: code,
    errorDesc: logger.errorDesc ?? "",
    other: "userId=$userId",
  );
}
```

内容以 JSON 行追加写入 `diskcacheErrorPath`：

```json
{"code":-3,"error":"mmap failed","other":"userId=123"}
```

```dart
void writeFail({required int code, required String errorDesc, String? other});
void deleteFailFile();  // 删除错误文件
void closeFailFile();   // 关闭写入流
```

> 路径无效（未初始化 / 已禁用 / 已销毁）时 `writeFail` 直接返回，不会误写到根目录。

## 2.8 解析日志文件

```dart
static List<Map<String, dynamic>> selectLogmsg({
  required String diskcacheFilePath,
  String? cryptKey,
  String? iv,
});
```

传入日志文件的完整路径和写入时用的加密参数（未加密则不传）。返回**时间倒序**（最新在前）的条目列表，每条包含：

| 字段 | 说明 |
|---|---|
| `name` | 日志名称 |
| `tag` | 标记 |
| `msg` | 日志内容 |
| `level` | 等级 |
| `timestamp` | 时间戳 |
| `thread_id` | 线程 id |
| `is_main_thread` | 是否主线程 |
| `error_code` | `"1"` 表示该条解析失败，通常是 `cryptKey`/`iv` 不对 |

这是同步的 FFI 调用，文件较大时会阻塞。建议放到 isolate 里：

```dart
final records = await Isolate.run(() => MXLogger.selectLogmsg(
      diskcacheFilePath: path,
      cryptKey: key,
      iv: iv,
    ));
```

配合 `logFiles` 就能在 App 内做一个日志查看器（example 里的 `log_viewer_page.dart` 就是这么实现的）。

> `selectLogfiles({required String directory})` 目前是未实现的占位接口，所有平台都返回空列表，请勿使用。

## 2.9 销毁

```dart
static void destroy({required String nameSpace, String? directory});
static void destroyWithLoggerKey(String loggerKey);
```

销毁会先失效对应的 Dart 实例（移除生命周期监听、关闭错误文件流、清空 native 句柄），再释放 native 对象。

这个顺序是必要的：如果先释放 native，App 随后进入后台触发的清理回调就会拿着已释放的指针调进 native，造成 use-after-free 崩溃。

同一 `nameSpace + directory` 重复构造出的多个 Dart 实例共享同一个 native 对象，`destroy` 会把它们**全部**失效，不会漏掉先前的实例。

---

# 解析日志文件（桌面工具）

产出的 `.mx` 二进制文件可以用 [mxlogger_analyzer](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer.dmg) 打开，支持按等级、name、tag 过滤和关键字检索。加密日志需要在工具里填入对应的 `cryptKey` / `iv`。

# 示例工程

`example/` 是一个完整的演示 App，覆盖了本文档提到的全部 API：初始化、五个等级写入、loggerKey 组件化写入、磁盘策略、文件列表、日志查看与解析、销毁。

```bash
cd example && flutter run
```

# License

BSD 3-Clause，见 [LICENSE](LICENSE)。
