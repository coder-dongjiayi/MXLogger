<p align="center">
  <img src="https://img.shields.io/badge/iOS-9.0+-000000?style=for-the-badge&logo=apple&logoColor=white" alt="iOS" />
  <img src="https://img.shields.io/badge/Android-minSdk%2021-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Flutter-3.3+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/%E8%A7%A3%E6%9E%90%E5%99%A8-macOS%20%7C%20Windows%20%7C%20Linux-6C5CE7?style=for-the-badge&logo=flutter&logoColor=white" alt="解析器桌面端" />
</p>

<p align="center">
  <a href="https://github.com/coder-dongjiayi/MXLogger/blob/main/LICENSE.TXT"><img src="https://img.shields.io/badge/license-BSD--3-brightgreen.svg?style=flat-square" alt="license" /></a>
  <a href="https://cocoapods.org/pods/MXLogger"><img src="https://img.shields.io/cocoapods/v/MXLogger?style=flat-square&label=pod" alt="CocoaPods" /></a>
  <a href="https://central.sonatype.com/artifact/io.github.coder-dongjiayi/mxlogger"><img src="https://img.shields.io/maven-central/v/io.github.coder-dongjiayi/mxlogger?style=flat-square&label=maven%20central" alt="Maven Central" /></a>
  <a href="https://pub.dev/packages/flutter_mxlogger"><img src="https://img.shields.io/pub/v/flutter_mxlogger?style=flat-square&label=pub&logo=dart" alt="pub" /></a>
  <a href="https://pub.dev/packages/mxlogger_analyzer_lib"><img src="https://img.shields.io/pub/v/mxlogger_analyzer_lib?style=flat-square&label=analyzer%20lib&logo=dart" alt="pub analyzer" /></a>
</p>

<p align="center" >
<img src="./icon/logo_400.png" alt="MXLogger"  title="MXLogger" width="180" />
</p>

# MXLogger

MXLogger 是基于 **mmap** 内存映射机制的跨平台日志库，支持 **AES-CFB-128** 加密，支持 iOS / Android /
Flutter。核心代码使用 C/C++ 实现，序列化使用 Google 开源的 **FlatBuffers**，Flutter 端通过 `dart:ffi`
直接调用，性能几乎与原生一致。iPhone 11 上写入 10 万条（每条约 134 字节）耗时约 **0.13s**。

配套提供 **mxlogger_analyzer** 日志解析器：导入、解密、检索产出的 `.mx` 二进制日志，既是桌面 app
（macOS/Windows/Linux），也能以悬浮球的形式直接嵌进你的 iOS/Android Flutter app 里看端上日志。

For English, click [here](./README.md).

- [日志解析器](#日志解析器)
- [安装引入](#安装引入)
- [快速开始](#快速开始)
- [API 一览](#api-一览)
  - [iOS](#ios-api) · [Android](#android-api) · [Flutter](#flutter-api) · [解析器](#analyzer-api)
- [存储策略与日志等级](#存储策略与日志等级)
- [性能测试](#性能测试)
- [注意事项](#注意事项)

## 整体结构

<img src="./icon/jiegoutu.jpg" alt="结构图" width="640" />

MXLogger 主要解决日志**写入**和日志**分析**两件事。至于日志上报时机应该由业务决定：MXLogger 已经把日志目录
（`diskCachePath`）暴露出来，由开发调用原生平台的文件上传代码传到自己的服务器，下载后再用
mxlogger_analyzer 解析。

---

# 日志解析器

`.mx` 是二进制文件（AES-CFB-128 + flatbuffer），必须用解析器打开。解析器把记录写入 sqlite，基于它提供
全文检索、等级/时间/Tag/Name 过滤和 JSON 语法树查看。

| 形态 | 说明 | 获取方式 |
| --- | --- | --- |
| 桌面 app | macOS/Windows/Linux 客户端，拖入或选择日志文件即可分析 | [Releases](https://github.com/coder-dongjiayi/MXLogger/releases)（CI 三端出包） |
| 嵌入宿主 app | iOS/Android Flutter app 内的悬浮球 + 底部弹窗 | pub.dev 依赖 `mxlogger_analyzer_lib` |

**数据页**：等级分布条 + 等级 chips、搜索与时间过滤、日志卡片内的 JSON 语法着色树、
`@name` / `#tag` 点击即过滤、单条信息 / 分享 / 全屏 / 复制。右上角可切换深浅主题。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_dark.png" alt="解析器数据页" width="900" />

**首次使用三步向导**：① 拖入或选择 `.mx` 文件 → ② 配置解密 KEY/IV（可添加多组，勾选框里的序号就是解密
尝试顺序）→ ③ 真实进度导入。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_wizard.png" alt="首次引导向导" width="900" />

**单条日志全屏详情**（Esc 关闭）：Name / Tags / 时间 / 等级 + 完整 JSON 树，可整条分享或复制。

<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/desktop_detail.png" alt="日志全屏详情" width="900" />

**嵌入宿主 app**（手机）：占屏 85% 的底部弹窗——留白收窄、文案让位于图标、等级 chips 横向滚动、
日志卡片默认折叠、四个操作收进「⋯」菜单。

<p align="center">
<img src="./mxlogger_analyzer/mxlogger_analyzer_lib/screenshots/mobile_embed.png" alt="嵌入式底部弹窗" width="340" />
</p>

解析器完整文档见 [mxlogger_analyzer_lib/README.zh-CN.md](./mxlogger_analyzer/mxlogger_analyzer_lib/README.zh-CN.md)。

---

# 安装引入

## iOS

```ruby
pod 'MXLogger', '~> 2.0.0'
```

## Android

```groovy
implementation 'io.github.coder-dongjiayi:mxlogger:latest.release'
```

## Flutter

```yaml
dependencies:
  flutter_mxlogger: ^2.0.0
  mxlogger_analyzer_lib: ^2.0.0   # 可选：app 内实时查看日志
```

原生依赖会自动引入，无需手动配置：iOS 端 CocoaPods 依赖 `MXLogger` → `MXLoggerCore`，
Android 端 Gradle 依赖 `io.github.coder-dongjiayi:mxlogger`。

---

# 快速开始

## iOS

```objective-c
MXLogger *logger = [MXLogger initializeWithNamespace:@"com.yourdomain.logger"
                                      storagePolicy:MXStoragePolicyYYYYMMDD
                                           fileName:@"mxlog"
                                         fileHeader:@"{\"app_version\":\"2.0.0\"}"
                                           cryptKey:@"abcuioqbsdguijlk"   // 16 字节
                                                 iv:@"bccuioqbsdguijiv"];

logger.consoleEnable = YES;                 // 仅开发期开启，性能测试/线上设为 NO
logger.maxDiskAge   = 60 * 60 * 24 * 7;     // 最多保留 7 天
logger.maxDiskSize  = 1024 * 1024 * 10;     // 最多占用 10M
logger.level        = 0;                    // 0:debug 全部写入文件

// 多个 tag 用英文逗号分隔
[logger debugWithName:@"login" msg:@"开始校验本地 token" tag:@"login,service"];
[logger infoWithName:@"network" msg:responseJSON tag:@"network,POST,200"];
[logger warnWithName:@"network" msg:@"第 2 次重试" tag:@"network"];
[logger errorWithName:@"flutter" msg:stack tag:@"crash"];
[logger fatalWithName:@"database" msg:@"数据库连接丢失" tag:@"db,fatal"];

NSLog(@"日志目录 %@", logger.diskCachePath);
```

## Android

```java
MXLogger logger = MXLogger.initialize(
        context,
        "com.yourdomain.logger",              // nameSpace
        null,                                 // diskCacheDirectory，null 用默认目录
        MXStoragePolicyType.YYYY_MM_DD,
        "mxlog",                              // fileName
        "{\"app_version\":\"2.0.0\"}",        // fileHeader
        "abcuioqbsdguijlk",                   // cryptKey，16 字节
        "bccuioqbsdguijiv");                  // iv

logger.setConsoleEnable(true);
logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

// 注意 Android 端 tag 在第一个参数：debug(tag, name, msg)
logger.debug("login,service", "login", "开始校验本地 token");
logger.info("network,POST,200", "network", responseJson);
logger.warn("network", "network", "第 2 次重试");
logger.error("crash", "flutter", stack);
logger.fatal("db,fatal", "database", "数据库连接丢失");

Log.d("MXLogger", "日志目录 " + logger.getDiskCachePath());
```

## Flutter

```dart
final MXLogger logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
  fileHeader: jsonEncode(deviceInfo),
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 字节
  iv: "bccuioqbsdguijiv",         // 不填默认与 cryptKey 一致
);

logger.setMaxDiskAge(60 * 60 * 24 * 7);
logger.setMaxDiskSize(1024 * 1024 * 10);
logger.setLevel(0);

logger.debug("开始校验本地 token", name: "login", tag: "login,service");
logger.info(jsonEncode(response), name: "network", tag: "network,POST,200");
logger.warn("第 2 次重试", name: "network", tag: "network");
logger.error(stack, name: "flutter", tag: "crash");
logger.fatal("数据库连接丢失", name: "database", tag: "db,fatal");

debugPrint("日志目录 ${logger.diskcachePath}");
```

---

# API 一览

三端共通的两个概念：一个 logger 由 **nameSpace + diskCacheDirectory** 唯一确定，底层 C++ 对象按这一对
去重；这一对的 md5 就是 **loggerKey**——大型 app 组件化时把它传给子模块，子模块用类方法写日志，不必传
logger 对象。

<a name="ios-api"></a>
## iOS —— `MXLogger`（Objective-C）

### 创建与释放

| API | 说明 |
| --- | --- |
| `+ initializeWithNamespace:` | 默认目录 `Library/com.mxlog.LoggerCache` |
| `+ initializeWithNamespace:fileHeader:` | 指定文件头信息 |
| `+ initializeWithNamespace:cryptKey:iv:fileHeader:` | 加密 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:` | 指定存储策略和文件名 |
| `+ initializeWithNamespace:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 存储策略 + 加密 |
| `+ initializeWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 全参数 |
| `- initWithNamespace:fileHeader:` | 实例初始化方法，参数组合同上 |
| `- initWithNamespace:diskCacheDirectory:fileHeader:` | |
| `- initWithNamespace:cryptKey:iv:fileHeader:` | |
| `- initWithNamespace:storagePolicy:fileName:fileHeader:` | |
| `- initWithNamespace:diskCacheDirectory:storagePolicy:fileName:fileHeader:cryptKey:iv:` | 完整初始化方法，其他方法最终都调它 |
| `+ destroyWithNamespace:` | 按 nameSpace 释放（默认目录） |
| `+ destroyWithNamespace:diskCacheDirectory:` | 按 nameSpace + 目录释放 |
| `+ destroyWithLoggerKey:` | 按 loggerKey 释放 |
| `+ valueForLoggerKey:` | 取已存在的 logger，不存在返回 `nil` |

### 属性

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `enable` | `BOOL` | 日志写入总开关 |
| `consoleEnable` | `BOOL` | 控制台输出，默认关闭；Release/Profile 构建已在编译期整段裁掉（需保留则定义 `MXLOGGER_CONSOLE_ENABLED=1`） |
| `level` | `NSInteger` | 写入文件的最低等级，0 debug … 4 fatal |
| `maxDiskAge` | `NSUInteger` | 最大存储时长（秒），0 不限制 |
| `maxDiskSize` | `NSUInteger` | 最大总字节数，0 不限制 |
| `shouldRemoveExpiredDataWhenEnterBackground` | `BOOL` | 进入后台是否自动清理，默认 `YES` |
| `diskCachePath` | `NSString`（只读） | 日志目录 |
| `logSize` | `NSUInteger`（只读） | 当前占用字节数 |
| `loggerKey` | `NSString`（只读） | nameSpace + 目录的 md5 |

### 写入

| API | 说明 |
| --- | --- |
| `- logWithLevel:name:msg:tag:` | 返回 0 成功，-1 扩容失败 / -2 解除映射失败 / -3 映射失败 |
| `- debugWithName:msg:tag:` | 等级 0 |
| `- infoWithName:msg:tag:` | 等级 1 |
| `- warnWithName:msg:tag:` | 等级 2 |
| `- errorWithName:msg:tag:` | 等级 3 |
| `- fatalWithName:msg:tag:` | 等级 4 |
| `+ debugWithLoggerKey:name:msg:tag:` | 通过 loggerKey 写入，无需持有 logger 对象 |
| `+ infoWithLoggerKey:name:msg:tag:` | |
| `+ warnWithLoggerKey:name:msg:tag:` | |
| `+ errorWithLoggerKey:name:msg:tag:` | |
| `+ fatalWithLoggerKey:name:msg:tag:` | |

### 文件、清理与解析

| API | 说明 |
| --- | --- |
| `- logFiles` | 字典数组：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `- errorDesc` | 最近一次写入失败的错误信息 |
| `- removeExpireData` | 先删过期文件，总大小仍超 `maxDiskSize` 则从最旧的继续删；正在写入的文件不删 |
| `- removeAllData` | 删除全部日志文件 |
| `- removeBeforeAllData` | 删除除当前正在写入外的所有文件 |
| `+ selectWithDiskCacheFilePath:cryptKey:iv:` | 解析日志文件（时间倒序）：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code` |

### `MXStoragePolicyType`

`MXStoragePolicyYYYYMMDD`（按天，默认）· `MXStoragePolicyYYYYMMDDHH`（按小时）·
`MXStoragePolicyYYYYWW`（按周）· `MXStoragePolicyYYYYMM`（按月）

<a name="android-api"></a>
## Android —— `com.dongjiayi.mxlogger.MXLogger`（Java）

### 创建与释放

| API | 说明 |
| --- | --- |
| `MXLogger(Context, String nameSpace, String diskCacheDirectory, MXStoragePolicyType, String fileName, String fileHeader, String cryptKey, String iv)` | 完整构造方法 |
| `MXLogger(Context, String nameSpace, String fileHeader)` | 默认目录 |
| `MXLogger(Context, String nameSpace, String fileHeader, String cryptKey, String iv)` | 加密 |
| `MXLogger(Context, String fileHeader, String nameSpace, String diskCacheDirectory)` | 自定义目录 |
| `static MXLogger initialize(Context, nameSpace, diskCacheDirectory, storagePolicy, fileName, fileHeader, cryptKey, iv)` | 全参数 |
| `static MXLogger initialize(Context, nameSpace, fileHeader)` | |
| `static MXLogger initialize(Context, nameSpace, fileHeader, cryptKey, iv)` | |
| `static void destroy(Context, String nameSpace, String diskCacheDirectory)` | 按 nameSpace + 目录释放 |
| `static void destroy(String loggerKey)` | 按 loggerKey 释放 |

### 配置与状态

配置项不在 Java 侧缓存：所有 getter 直接查询 native（多个 Java 实例可能共享同一个 native 对象，
native 是唯一事实源）。

| API | 说明 |
| --- | --- |
| `void setEnable(boolean)` / `boolean isEnable()` | 日志写入总开关 |
| `void setConsoleEnable(boolean)` / `boolean isConsoleEnable()` | 控制台输出 |
| `void setLevel(int)` / `int getLevel()` | 写入文件的最低等级，0 debug … 4 fatal |
| `void setMaxDiskAge(long)` / `long getMaxDiskAge()` | 最大存储时长（秒），0 不限制 |
| `void setMaxDiskSize(long)` / `long getMaxDiskSize()` | 最大总字节数，0 不限制 |
| `long getLogSize()` | 当前占用字节数 |
| `String getDiskCachePath()` | 日志目录 |
| `String getLoggerKey()` | nameSpace + 目录的 md5 |
| `String getErrorDesc()` | 最近一次写入失败的错误信息 |

### 写入

注意参数顺序：Android 端 **tag 在第一个参数**。

| API | 说明 |
| --- | --- |
| `int debug(String tag, String name, String msg)` | 等级 0 |
| `int info(String tag, String name, String msg)` | 等级 1 |
| `int warn(String tag, String name, String msg)` | 等级 2 |
| `int error(String tag, String name, String msg)` | 等级 3 |
| `int fatal(String tag, String name, String msg)` | 等级 4 |
| `int log(String tag, int level, String name, String msg)` | 返回 0 成功，-1 / -2 / -3 失败 |
| `static int log(String loggerKey, String tag, int level, String name, String msg)` | 通过 loggerKey 写入 |

### 文件、清理与解析

| API | 说明 |
| --- | --- |
| `String[] logFiles()` | 每个元素是一个文件的 JSON 字符串：`name` / `size` / `last_timestamp` / `create_timestamp` |
| `void removeExpireData()` | 先删过期文件，超出 `maxDiskSize` 再从最旧的继续删。Android 端没有生命周期钩子，需自行调用（如 `onStop`） |
| `void removeAll()` | 删除全部日志文件 |
| `void removeBeforeAllData()` | 删除除当前正在写入外的所有文件 |
| `static String[] selectWithFilePath(String diskCacheFilePath, String cryptKey, String iv)` | 解析日志文件，每个元素是一条日志的 JSON 字符串（时间倒序） |

### `MXStoragePolicyType`

`YYYY_MM_DD`（按天）· `YYYY_MM_DD_HH`（按小时）· `YYYY_WW`（按周）· `YYYY_MM`（按月）

<a name="flutter-api"></a>
## Flutter —— `flutter_mxlogger`

所有读写都走 `dart:ffi`，MethodChannel 只在 `initialize` 时用来获取平台默认目录。

### 创建与释放

| API | 说明 |
| --- | --- |
| `static Future<MXLogger> initialize({required String nameSpace, String? directory, bool consoleEnable = false, MXStoragePolicyType storagePolicy = yyyy_MM_dd, String? fileName, String? fileHeader, String? cryptKey, String? iv})` | 推荐用法，自动获取平台默认目录（iOS `Library/com.mxlog.LoggerCache/nameSpace`，Android `files/com.mxlog.LoggerCache/nameSpace`） |
| `MXLogger({required String nameSpace, required String directory, ...})` | 同步构造方法，必须显式给目录 |
| `static void destroy({required String nameSpace, String? directory})` | 释放；会先失效对应的 Dart 实例，避免 use-after-free |
| `static void destroyWithLoggerKey(String loggerKey)` | 按 loggerKey 释放 |

### Getter

| Getter | 类型 | 说明 |
| --- | --- | --- |
| `enable` | `bool` | 日志写入是否开启 |
| `consoleEnable` | `bool` | 控制台输出是否开启 |
| `diskcachePath` | `String` | 日志目录（directory + nameSpace） |
| `diskcacheErrorPath` | `String` | 本地错误文件 `error.txt` 路径 |
| `loggerKey` | `String?` | nameSpace + 目录的 md5 |
| `logSize` | `int` | 当前占用字节数 |
| `logFiles` | `List<MXFileEntity>` | 日志文件列表 |
| `errorDesc` | `String?` | 最近一次 native 写入错误，无错误返回 `null` |
| `cryptKey` / `iv` | `String?` | 初始化时传入的加密参数，可直接交给解析器 |

### 开关与磁盘管理

| API | 说明 |
| --- | --- |
| `void setEnable(bool enable)` | 日志写入总开关 |
| `void setConsoleEnable(bool enable)` | 控制台输出；release/profile 构建整段被 tree-shake |
| `void setLevel(int lvl)` | 写入文件的最低等级，0 debug … 4 fatal |
| `void setMaxDiskAge(int age)` | 最大存储时长（秒），0 不限制 |
| `void setMaxDiskSize(int size)` | 最大总字节数，0 不限制 |
| `void shouldRemoveExpiredDataWhenEnterBackground(bool should)` | 进入后台是否自动清理，默认 `true` |
| `void removeExpireData()` | 先删过期文件，超出大小限制再从最旧的继续删 |
| `void removeAll()` | 删除全部日志文件 |
| `void removeBeforeAllData()` | 删除除当前正在写入外的所有文件 |
| `int getLogSize()` / `String getDiskcachePath()` / `String? getLoggerKey()` / `List<MXFileEntity> getLogFiles()` | 上面几个 getter 的方法形式 |

### 写入

| API | 说明 |
| --- | --- |
| `int debug(String msg, {String? name, String? tag})` | 等级 0 |
| `int info(String msg, {String? name, String? tag})` | 等级 1 |
| `int warn(String msg, {String? name, String? tag})` | 等级 2 |
| `int error(String msg, {String? name, String? tag})` | 等级 3 |
| `int fatal(String msg, {String? name, String? tag})` | 等级 4 |
| `int log(int lvl, String msg, {String? name, String? tag})` | 返回 0 成功，-1 扩容失败 / -2 解除映射失败 / -3 映射失败 |
| `static void logLoggerKey(String? loggerKey, int lvl, String msg, {String? name, String? tag})` | 通过 loggerKey 写入 |
| `static void debugLog(String? loggerKey, String msg, {String? name, String? tag})` | 另有 `infoLog` / `warnLog` / `errorLog` / `fatalLog`，签名一致 |

### 写入失败记录与解析

| API | 说明 |
| --- | --- |
| `void writeFail({required int code, required String errorDesc, String? other})` | `log` 返回值 != 0 时调用，把失败信息以 JSON 行追加到 `diskcacheErrorPath` |
| `void deleteFailFile()` | 删除本地错误文件 |
| `void closeFailFile()` | 关闭错误文件的写入流 |
| `static List<Map<String, dynamic>> selectLogmsg({required String diskcacheFilePath, String? cryptKey, String? iv})` | 解析日志文件（时间倒序）：`name` / `msg` / `tag` / `level` / `timestamp` / `thread_id` / `is_main_thread` / `error_code`；`error_code == "1"` 表示该条解析失败（多为 cryptKey 或 iv 不正确） |
| `static List<Map<String, dynamic>> selectLogfiles({required String directory})` | **未实现**，各平台均返回空列表，获取文件信息请用 `logFiles` |

### `MXFileEntity`

`name`（`String?`）· `size`（`int`，字节）· `createTimeStamp` / `lastTimeStamp`（`int`，秒）·
`createTime` / `lastTime`（`DateTime`，由时间戳换算）

### `MXStoragePolicyType`

`yyyy_MM_dd`（按天，默认）· `yyyy_MM_dd_HH`（按小时）· `yyyy_ww`（按周）· `yyyy_MM`（按月）

<a name="analyzer-api"></a>
## 解析器 —— `mxlogger_analyzer_lib`

### 嵌入宿主 app：`MXAnalyzer`

| API | 说明 |
| --- | --- |
| `static void initialize({String? databasePath, MXPrefs? prefs})` | 可选预配置：sqlite 目录（不传默认 `getApplicationSupportDirectory()`）、主题/语言/解密参数的持久化实现（不传只存内存） |
| `static Future<void> showDebug(OverlayState overlayState, {required String diskcachePath, required List<MxCryptPair> cryptPairs, required MXShareHandler onShare, String? databasePath})` | 显示悬浮球（拖动移动、单击开弹窗、双击移除）；悬浮球已存在时重复调用直接忽略 |
| `static void dismiss()` | 移除悬浮球并释放数据库 |

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,
  // 日志未加密传空数组；换过密钥可传多组，解析时逐条按顺序尝试，
  // 所以同一个文件里用不同 Key/IV 写的记录也能全部解出来
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  onShare: _shareWithSharePlus,   // 返回 false 则降级为复制到剪贴板
);

MXAnalyzer.dismiss();
```

打开弹窗**不会**自动解析：由用户点「刷新」扫描 `diskcachePath` 下的 `.mx` 文件，每次刷新都清空数据库
重新解析，所见即本次扫描的全量结果。结果落在 sqlite，App 重启后再打开仍能看到上次的结果。

### 宿主相关类型

| 类型 | 说明 |
| --- | --- |
| `MxCryptPair({required String key, String iv = ""})` | 一组解密参数；`iv` 为空时按 native 约定回退为 `key` |
| `MXShareHandler` = `Future<bool> Function(MXShareRequest)` | 分享实现由宿主注入，返回 `false` 降级为复制到剪贴板 |
| `MXShareRequest` | `title` / `text` / `fileName`（非空表示分享文本文件）/ `origin`（触发控件的屏幕矩形，iPad/macOS 的 popover 分享面板需要） |
| `MXHost({required MXPrefs prefs, MXPickLogFiles? pickLogFiles, MXDropTargetBuilder? dropTargetBuilder, MXShareHandler? share})` | 桌面壳的能力注入；缺哪个能力就少哪个入口，而不是抛异常 |
| `MXPrefs` / `MXMemoryPrefs` | 设置持久化接口，默认使用内存实现 |
| `MXStore` / `MXScope` / `MXState` / `MXAsyncState` | 基于 stream 的轻量状态管理，自定义嵌入方式时使用 |
| `MXLoggerAnalyzerApp` | 完整的解析器 app，自定义桌面壳时使用 |

---

# 存储策略与日志等级

**存储策略**决定日志文件如何切分和命名：

| 策略 | 文件名 | |
| --- | --- | --- |
| 按天（默认） | `2023-01-11_mxlog.mx` | 一天一个文件 |
| 按小时 | `2023-01-11-15_mxlog.mx` | 一小时一个文件 |
| 按周 | `2023-01-02w_mxlog.mx` | `02w` 指一年中的第 2 周 |
| 按月 | `2023-01_mxlog.mx` | 一个月一个文件 |

**日志等级**为 `0:debug 1:info 2:warn 3:error 4:fatal`。设置 level = n 表示只有 >= n 的日志会被写入
文件：比如 `level = 2`，`debug` 和 `info` 会被丢弃，只写入 `warn` `error` `fatal`。该字段只针对**磁盘
写入**生效，开启控制台输出后控制台仍会打印全部日志。

**控制台输出**只面向开发期。它会影响写入效率，做性能测试时务必关闭；线上包三端都会在编译期把这段裁掉。

**加密**使用 AES-CFB-128，代码来自 [MMKV](https://github.com/Tencent/MMKV/tree/master/Core/aes)，
汇编实现，最大程度保障写入性能。`cryptKey` 和 `iv` 为 16 字节——超过自动截断，不足补 0；`iv` 不填时默认
与 `cryptKey` 一致。这两个值要留好：解析器需要同一组参数才能读回文件。

**文件头信息**（`fileHeader`）在文件创建时写入一次，适合放环境信息（app 版本、平台、设备信息），
解析器会把它展开成标量紧凑网格 + JSON 树。

---

# 性能测试

### 对比 Xlog 和 Logan

写入测试，以下仅为 iOS 端结果（性能测试 demo 代码点[这里](./性能测试demo.zip)下载）：

- 测试设备 iPhone 11，系统版本 14.6，Xcode Build Configuration 为 release
- 每条数据约 134 字节，for 循环 10 万次
- 测试 10 次取平均值

| | MXLogger | Xlog | Logan |
| --- | --- | --- | --- |
| 写入耗时 | **约 0.13s** | 约 0.57s | 约 14.0s |
| 文件体积 | 14008320 byte (14M) | 905753 byte (0.9M) | 922452 byte (0.9M) |

<img src="./icon/haoshi.jpg" alt="耗时对比" width="520" />

Logan 和 Xlog 对数据做了压缩，实际体积会小很多。日志压缩在 MXLogger 的后续迭代计划里。

---

# 注意事项

- 日志目录**不要**设置在可能被系统清理的目录，比如 iOS 的 `Library/Caches`。MXLogger 只在启动时创建
  目录，不会在每次写入时检测——如果 app 运行中目录被系统清理，程序不会报错也不会闪退，但日志也不会被记录。
- 一个 **nameSpace + diskCacheDirectory** 只对应一个 logger：重复初始化拿到的是同一个 native 对象的
  包装，通过任意一个改配置对其他实例同样生效。
- `nameSpace` 建议使用域名反转保证唯一性。
- 组件化工程把 **loggerKey** 传给子模块，子模块用类方法写日志，不必传 logger 对象。
- `maxDiskAge` / `maxDiskSize` 不是每次写入都校验：清理发生在 `removeExpireData`（iOS 与 Flutter 进入
  后台自动调用，Android 需自行调用）。

# 后续版本迭代安排

1. 日志文件压缩

# 参考代码

- [MMKV](https://github.com/Tencent/MMKV)
- [spdlog](https://github.com/gabime/spdlog)
- [log4cplus](https://github.com/log4cplus/log4cplus)
- [SDWebImage](https://github.com/SDWebImage/SDWebImage)
- [KSCrash](https://github.com/kstenerud/KSCrash)

# 开源协议

MXLogger 使用 BSD 3-Clause 协议，详见 [LICENSE.TXT](./LICENSE.TXT)。
