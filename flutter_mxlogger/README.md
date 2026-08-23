# flutter_mxlogger

中文说明请点击[这里](./README_CN.md)。

MXLogger is a cross-platform logging library built on mmap memory mapping, with AES-CFB-128 encryption. The core is written in C/C++ and serializes records with Google FlatBuffers; the Flutter side calls straight into it through `dart:ffi`, so performance is essentially identical to native.

See the [main MXLogger repository](https://github.com/coder-dongjiayi/MXLogger) for the full project.

- **Version**: 2.0.0
- **Requirements**: Dart SDK `>=2.18.0 <4.0.0`, Flutter `>=3.3.0`
- **Platforms**: iOS (>= 9.0), Android (minSdk 21)

## Installation

```yaml
dependencies:
  flutter_mxlogger: ^2.0.0
```

The native dependencies are pulled in automatically — no manual setup required:

- iOS: CocoaPods depends on `MXLogger 2.0.0` → `MXLoggerCore 2.0.0`
- Android: Gradle depends on `io.github.coder-dongjiayi:mxlogger:2.0.0`

## Quick start

```dart
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

final logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyy_MM_dd_HH,
  consoleEnable: true,
  cryptKey: "abcuioqbsdguijlk",   // 16 bytes
  iv: "bccuioqbsdguijiv",         // defaults to cryptKey when omitted
);

logger.setMaxDiskAge(60 * 60 * 24 * 7); // keep at most 7 days
logger.setMaxDiskSize(1024 * 1024 * 10); // use at most 10 MB
logger.setLevel(0);                      // 0:debug — write everything to file

logger.debug("this is debug message", name: "mxlogger", tag: "net,response");
logger.info("this is info message", name: "mxlogger", tag: "tag1,tag2");
logger.warn("this is warn message");
logger.error("this is error message");
logger.fatal("this is fatal message");
```

---

# 1. Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Dart      lib/src/flutter_mxlogger.dart                     │
│  · MethodChannel("flutter_mxlogger") — default directory only│
│  · dart:ffi — every read/write, zero channel overhead        │
│  · WidgetsBindingObserver — cleanup when entering background │
└──────────────┬───────────────────────────┬───────────────────┘
               │ ffi lookup                │ ffi lookup
               │ (symbols prefixed flutter_mxlogger_)          │
┌──────────────▼──────────────┐ ┌──────────▼───────────────────┐
│ iOS  flutter-bridge.mm      │ │ Android flutter-bridge.cpp   │
│ bridges Objective-C MXLogger│ │ bridges C++ mx_logger        │
└──────────────┬──────────────┘ └──────────┬───────────────────┘
               │                           │
        ┌──────▼───────────────────────────▼──────┐
        │  Core (C/C++): mmap + AES-CFB-128       │
        │  + FlatBuffers serialization            │
        └─────────────────────────────────────────┘
```

The key point: **there is no MethodChannel on the log-writing path**. `log()` is a synchronous FFI call all the way from Dart to disk — no message queue, no codec encoding, and no waiting on the platform thread.

---

# 2. Dart API

## 2.1 Initialization

### `MXLogger.initialize` (recommended)

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

| Parameter | Description |
|---|---|
| `nameSpace` | Namespace of the log files; a reverse-domain name is recommended for uniqueness. The final directory is `directory/nameSpace` |
| `directory` | Custom directory. When omitted, the platform default is resolved over the MethodChannel: iOS `<Library>/com.mxlog.LoggerCache`, Android `<filesDir>/com.mxlog.LoggerCache` |
| `consoleEnable` | Whether to print to the console; effective in debug builds only |
| `storagePolicy` | File split policy, see 2.2 |
| `fileName` | Custom file name, defaults to `mxlog` |
| `fileHeader` | File header, written once when the file is **created**. A good place for app version, platform, device model and similar context |
| `cryptKey` | AES key. **16 bytes: truncated if longer, zero-padded if shorter.** Omit for unencrypted logs |
| `iv` | Initialization vector, same rules as `cryptKey`. Defaults to `cryptKey` when omitted |

> ⚠️ Zero-padding a `cryptKey` / `iv` shorter than 16 bytes was only fully fixed in v2.0.0. Older logs written with a short key may not be readable by the analyzer — prefer a full 16 bytes.

### Synchronous constructor

```dart
MXLogger({required String nameSpace, required String directory, ...})
```

`directory` is required, no MethodChannel is involved, and the call is synchronous.

**Initialization never throws.** When native returns a null handle (for example the directory cannot be created), the instance is automatically set to `enable == false`; every later call short-circuits safely and no null pointer is ever passed into native code. Check `logger.enable` to detect this.

## 2.2 Storage policy — `MXStoragePolicyType`

| Value | Granularity | Example file name |
|---|---|---|
| `yyyy_MM_dd` (default) | per day | `2023-01-11_mxlog.mx` |
| `yyyy_MM_dd_HH` | per hour | `2023-01-11-15_mxlog.mx` |
| `yyyy_ww` | per week | `2023-01-02w_mxlog.mx` (`02w` = 2nd week of the year) |
| `yyyy_MM` | per month | `2023-01_mxlog.mx` |

## 2.3 Writing logs

### Instance methods

```dart
int debug(String msg, {String? name, String? tag});
int info (String msg, {String? name, String? tag});
int warn (String msg, {String? name, String? tag});
int error(String msg, {String? name, String? tag});
int fatal(String msg, {String? name, String? tag});

int log(int lvl, String msg, {String? name, String? tag});
```

- `lvl`: `0` debug, `1` info, `2` warn, `3` error, `4` fatal
- `name`: logger name, usually the module name
- `tag`: tags, comma-separated for multiple values (`"net,response"`); the analyzer can filter by tag
- If `msg` is valid JSON, the console pretty-prints it with indentation

**Return value:**

| Value | Meaning |
|---|---|
| `0` | Success |
| `-1` | File expansion failed |
| `-2` | Unmap failed |
| `-3` | mmap failed |

### Class methods (modularized apps)

In a large app split into modules, sub-modules often cannot conveniently hold the logger object. Pass the `loggerKey` string instead:

```dart
// main project
final key = logger.loggerKey;   // store it, or register it in a global service

// sub-module — no dependency on the logger instance
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

The same `loggerKey` works on the native side too — `FlutterMxloggerPlugin.info(...)` on Android, `[FlutterMxloggerPlugin info:...]` on iOS — writing into the same file.

## 2.4 Switches and levels

```dart
void setLevel(int lvl);        // only logs with level >= lvl are written to file
void setEnable(bool enable);   // master switch; nothing is written when false
void setConsoleEnable(bool enable);
void shouldRemoveExpiredDataWhenEnterBackground(bool should); // defaults to true
```

- `setLevel(2)` means only warn and above reach the disk; debug/info are dropped. **This does not affect the console** — every level is still printed there.
- `setConsoleEnable` writes to a **static field**, so it applies globally to all logger instances; the `consoleEnable` passed when constructing a logger overwrites that global value as well.

> 🔁 Migrating from 1.x: `setFileLevel(int)` has been renamed to `setLevel(int)`; the semantics are unchanged.

## 2.5 Disk management

```dart
void setMaxDiskAge(int seconds);  // defaults to 0 = unlimited
void setMaxDiskSize(int bytes);   // defaults to 0 = unlimited

void removeExpireData();      // clean up according to the two thresholds above
void removeBeforeAllData();   // delete every log file except the one being written
void removeAll();             // delete all log files
```

`removeExpireData()` cleans up in two steps: first it deletes files whose last-modified time is older than `maxDiskAge`; if the total size still exceeds `maxDiskSize`, it keeps deleting from the oldest file onward. **The file currently being written is never deleted.**

It is called automatically once when the app enters background; turn that off with `shouldRemoveExpiredDataWhenEnterBackground(false)`.

## 2.6 State

| Member | Type | Description |
|---|---|---|
| `enable` | `bool` | Whether logging is available |
| `consoleEnable` | `bool` | Console switch (global) |
| `loggerKey` | `String?` | Unique key of the underlying logger, for passing between modules |
| `diskcachePath` | `String` | Log directory (`directory` + `nameSpace`) |
| `diskcacheErrorPath` | `String` | Path of the error-record file, i.e. `diskcachePath/error.txt` |
| `logSize` | `int` | Total size of stored logs in bytes |
| `logFiles` | `List<MXFileEntity>` | List of log files |
| `errorDesc` | `String?` | Description of the most recent write failure; `null` when there is none |
| `cryptKey` / `iv` | `String?` | The encryption parameters passed at initialization |

### `MXFileEntity`

```dart
class MXFileEntity {
  String? name;          // file name
  int size;              // size in bytes
  int createTimeStamp;   // creation timestamp (seconds)
  int lastTimeStamp;     // last-modified timestamp (seconds)

  DateTime get createTime;
  DateTime get lastTime;
}
```

## 2.7 Recording write failures

When `log()` returns a non-zero value the entry was not written. You can record the failure into a separate plain-text file for later investigation:

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

Entries are appended as JSON lines to `diskcacheErrorPath`:

```json
{"code":-3,"error":"mmap failed","other":"userId=123"}
```

```dart
void writeFail({required int code, required String errorDesc, String? other});
void deleteFailFile();  // delete the error file
void closeFailFile();   // close the write stream
```

> When the path is invalid (uninitialized, disabled or destroyed), `writeFail` returns immediately instead of writing to the filesystem root.

## 2.8 Parsing log files

```dart
static List<Map<String, dynamic>> selectLogmsg({
  required String diskcacheFilePath,
  String? cryptKey,
  String? iv,
});
```

Pass the full path of the log file plus the encryption parameters it was written with (omit them for unencrypted files). Entries are returned **newest first**, each containing:

| Field | Description |
|---|---|
| `name` | Logger name |
| `tag` | Tags |
| `msg` | Log message |
| `level` | Level |
| `timestamp` | Timestamp |
| `thread_id` | Thread id |
| `is_main_thread` | Whether it was the main thread |
| `error_code` | `"1"` means the entry failed to decode, usually a wrong `cryptKey` / `iv` |

This is a synchronous FFI call and will block on large files. Run it in an isolate:

```dart
final records = await Isolate.run(() => MXLogger.selectLogmsg(
      diskcacheFilePath: path,
      cryptKey: key,
      iv: iv,
    ));
```

Combined with `logFiles` this is enough to build an in-app log viewer — that is exactly what `log_viewer_page.dart` in the example does.

> `selectLogfiles({required String directory})` is an unimplemented stub that returns an empty list on every platform. Do not use it.

## 2.9 Destroying a logger

```dart
static void destroy({required String nameSpace, String? directory});
static void destroyWithLoggerKey(String loggerKey);
```

Destroying first invalidates the matching Dart instances (removes the lifecycle observer, closes the error-file sink, clears the native handle) and only then releases the native object.

That order matters: releasing native first would leave the enter-background cleanup callback calling into native code with a freed pointer, crashing with a use-after-free.

Multiple Dart instances constructed with the same `nameSpace + directory` share one native object, and `destroy` invalidates **all** of them — earlier instances are not left behind.

---

# Desktop analyzer

The `.mx` binary files can be opened with [mxlogger_analyzer](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer.dmg), which supports filtering by level, name and tag, plus keyword search. For encrypted logs, enter the matching `cryptKey` / `iv` in the tool.

# Example

`example/` is a complete demo app covering every API in this document: initialization, all five levels, loggerKey-based writes for modularized apps, storage policies, the file list, the log viewer and parsing, and destruction.

```bash
cd example && flutter run
```

# License

BSD 3-Clause, see [LICENSE](LICENSE).
