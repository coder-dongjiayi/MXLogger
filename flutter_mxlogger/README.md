# flutter_mxlogger

English | [简体中文](./README_CN.md) | [日本語](./README_JA.md) | [한국어](./README_KO.md)

MXLogger is a cross-platform logging library built on mmap memory mapping, with AES-CFB-128 encryption. The core is written in C/C++ and serializes records with Google FlatBuffers; the Flutter side calls straight into it through `dart:ffi`, so performance is essentially identical to native.

See the [main MXLogger repository](https://github.com/coder-dongjiayi/MXLogger) for the full project.

- **Version**: 2.1.0
- **Requirements**: Dart SDK `>=2.18.0 <4.0.0`, Flutter `>=3.3.0`
- **Platforms**: iOS (>= 9.0), Android (minSdk 21)

## Contents

- [Installation](#installation)
- [Quick start](#quick-start)
- [1. Architecture](#1-architecture)
- [2. Dart API](#2-dart-api)
  - [2.1 Initialization](#21-initialization)
  - [2.2 Storage policy — `MXStoragePolicyType`](#22-storage-policy--mxstoragepolicytype)
  - [2.3 Writing logs](#23-writing-logs)
  - [2.4 Switches and levels](#24-switches-and-levels)
  - [2.5 Disk management](#25-disk-management)
  - [2.6 State](#26-state)
  - [2.7 Recording write failures](#27-recording-write-failures)
  - [2.8 Parsing log files](#28-parsing-log-files)
  - [2.9 Destroying a logger](#29-destroying-a-logger)
- [3. `loggerToken`: sharing one logger across modules and languages](#3-loggertoken-sharing-one-logger-across-modules-and-languages)
  - [3.1 What it is](#31-what-it-is)
  - [3.2 Writing from sub-modules (Dart)](#32-writing-from-sub-modules-dart)
  - [3.3 Writing from native code (Android / iOS)](#33-writing-from-native-code-android--ios)
  - [3.4 Lifetime](#34-lifetime)
- [4. Parsing `.mx` log files](#4-parsing-mx-log-files)
  - [4.1 Where the files are](#41-where-the-files-are)
  - [4.2 Desktop analyzer (macOS / Windows / Linux)](#42-desktop-analyzer-macos--windows--linux)
  - [4.3 In-app analyzer (`mxlogger_analyzer_lib`)](#43-in-app-analyzer-mxlogger_analyzer_lib)
  - [4.4 Parsing in Dart](#44-parsing-in-dart)
- [Example](#example)
- [License](#license)

## Installation

```yaml
dependencies:
  flutter_mxlogger: ^2.1.0
```

The native dependencies are pulled in automatically — no manual setup required:

- iOS (CocoaPods, default): depends on `MXLogger 2.1.0` → `MXLoggerCore 2.1.0`
- iOS (Swift Package Manager): when the host app has enabled Flutter's SwiftPM support (`flutter config --enable-swift-package-manager`), the plugin is integrated via `ios/flutter_mxlogger/Package.swift` and depends on [MXLogger-SwiftPM](https://github.com/coder-dongjiayi/MXLogger-SwiftPM) `2.1.0` instead
- Android: Gradle depends on `io.github.coder-dongjiayi:mxlogger:2.1.0`

## Quick start

```dart
import 'package:flutter_mxlogger/flutter_mxlogger.dart';

final logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyyMMddHH,
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
  MXStoragePolicyType storagePolicy = MXStoragePolicyType.yyyyMMdd,
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
| `yyyyMMdd` (default) | per day | `2023-01-11_mxlog.mx` |
| `yyyyMMddHH` | per hour | `2023-01-11-15_mxlog.mx` |
| `yyyyWw` | per week | `2023-01-02w_mxlog.mx` (`02w` = 2nd week of the year) |
| `yyyyMM` | per month | `2023-01_mxlog.mx` |

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

In a large app split into modules, sub-modules often cannot conveniently hold the logger object. Pass the `loggerToken` string instead:

```dart
// main project
final token = logger.loggerToken;   // store it, or register it in a global service

// sub-module — no dependency on the logger instance
MXLogger.infoLog(token, "module message", name: "user_module", tag: "login");
```

```dart
static void logLoggerToken(String? loggerToken, int lvl, String msg, {String? name, String? tag});
static void debugLog(String? loggerToken, String msg, {String? name, String? tag});
static void infoLog (String? loggerToken, String msg, {String? name, String? tag});
static void warnLog (String? loggerToken, String msg, {String? name, String? tag});
static void errorLog(String? loggerToken, String msg, {String? name, String? tag});
static void fatalLog(String? loggerToken, String msg, {String? name, String? tag});
```

The same `loggerToken` works on the native side too — `FlutterMxloggerPlugin.info(...)` on Android, `[FlutterMxloggerPlugin info:...]` on iOS — writing into the same file. [Section 3](#3-loggertoken-sharing-one-logger-across-modules-and-languages) explains what the token is, how long it stays valid and how to use it from native code.

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
| `loggerToken` | `String?` | Unique token of the underlying logger, for passing between modules |
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

Combined with `logFiles` this is enough to build an in-app log viewer — that is exactly what `log_viewer_page.dart` in the example does. If you would rather not write a UI, [section 4](#4-parsing-mx-log-files) covers the ready-made desktop and in-app analyzers.

> `selectLogfiles({required String directory})` is an unimplemented stub that returns an empty list on every platform. Do not use it.

## 2.9 Destroying a logger

```dart
static void destroy({required String nameSpace, String? directory});
static void destroyWithLoggerToken(String loggerToken);
```

Destroying first invalidates the matching Dart instances (removes the lifecycle observer, closes the error-file sink, clears the native handle) and only then releases the native object.

That order matters: releasing native first would leave the enter-background cleanup callback calling into native code with a freed pointer, crashing with a use-after-free.

Multiple Dart instances constructed with the same `nameSpace + directory` share one native object, and `destroy` invalidates **all** of them — earlier instances are not left behind.

---

# 3. `loggerToken`: sharing one logger across modules and languages

## 3.1 What it is

`loggerToken` is a string that identifies one native logger. The C++ core derives it from the log directory: `md5(directory/nameSpace)`, i.e. the MD5 of `diskcachePath`. That has three consequences:

- The same `nameSpace` + `directory` always gives the same token, on every launch and on iOS and Android alike. A different directory gives a different token.
- The core keeps a global table `token → logger`. Every API that accepts a token looks the logger up there, so a token only works while that logger is initialized in the current process.
- It is not a secret and has nothing to do with `cryptKey` / `iv`. Storing it, passing it between modules or printing it is fine.

Read it with `logger.loggerToken` (or `getLoggerToken()`). It is `null` when the instance is disabled, for example because initialization failed (2.1).

## 3.2 Writing from sub-modules (Dart)

In a modularized app the main project owns the logger and knows the directory and encryption settings; sub-modules should depend on neither. Hand them the token and let them use the class methods listed in 2.3:

```dart
// main project: initialize once, publish the token
final logger = await MXLogger.initialize(nameSpace: "com.example.app", cryptKey: key, iv: iv);
AppServices.loggerToken = logger.loggerToken;   // any service locator / DI container works

// sub-module: knows nothing about how MXLogger was configured
MXLogger.infoLog(AppServices.loggerToken, "user tapped pay", name: "pay", tag: "ui");
MXLogger.errorLog(AppServices.loggerToken, "payment failed: $error", name: "pay", tag: "order");
```

Every entry lands in the same file and follows the same level filter, encryption and console switch as the main project's instance. A `null` or unknown token makes the class methods drop the entry; nothing is thrown.

## 3.3 Writing from native code (Android / iOS)

The token is computed in the shared C++ core, so the native layers understand the same string. Pass it over your own channel (MethodChannel, Pigeon, a native singleton, ...) and write straight into the Flutter logger's file:

```java
// Android: com.coderdjy.mxlogger.FlutterMxloggerPlugin
FlutterMxloggerPlugin.info(loggerToken, /*tag*/ "network", /*name*/ "okhttp", /*msg*/ "GET /user 200");
```

```objc
// iOS: FlutterMxloggerPlugin.h
[FlutterMxloggerPlugin info:loggerToken name:@"URLSession" msg:@"GET /user 200" tag:@"network"];
```

Mind the parameter order: Android is `(token, tag, name, msg)`, iOS is `(token, name, msg, tag)`. Both expose `debug` / `info` / `warn` / `error` / `fatal`. If the native code links the MXLogger SDK itself, the SDK's own token methods work as well: `MXLogger.log(token, tag, level, name, msg)` on Android, `[MXLogger infoWithLoggerToken:name:msg:tag:]` (Swift: `MXLogger.info(loggerToken:name:message:tag:)`) on iOS.

## 3.4 Lifetime

- A token is valid from `MXLogger.initialize` until `destroy` / `destroyWithLoggerToken` (2.9). Constructing the same `nameSpace` + `directory` twice reuses one native logger, so both Dart instances report the same token.
- `MXLogger.destroyWithLoggerToken(token)` is the destroy for code that only holds the string. It invalidates every Dart instance behind that token (`enable` becomes `false`, later calls are no-ops) and frees the native object; writes with that token are dropped from then on.
- Re-initializing with the same parameters yields the identical token string and writes resume. A stored token therefore never goes stale across launches, but it only works once the main project has initialized the logger in this process.

Quick reference:

| Need | API |
|---|---|
| Get the token | `logger.loggerToken` |
| Write from Dart | `MXLogger.debugLog / infoLog / warnLog / errorLog / fatalLog(token, msg, name:, tag:)`, `MXLogger.logLoggerToken(token, lvl, msg, name:, tag:)` |
| Write from Android | `FlutterMxloggerPlugin.debug / info / warn / error / fatal(token, tag, name, msg)` |
| Write from iOS | `[FlutterMxloggerPlugin debug / info / warn / error / fatal:token name: msg: tag:]` |
| Destroy by token | `MXLogger.destroyWithLoggerToken(token)` |

# 4. Parsing `.mx` log files

A `.mx` file is not text. Every record is a flatbuffer, and the whole file is AES-CFB-128 encrypted when the logger was created with `cryptKey` / `iv`, so an editor only shows binary noise. Three readers are available; pick by scenario:

| Scenario | Use |
|---|---|
| A file pulled from a device or uploaded by a user, analyzed on a computer | [4.2 Desktop analyzer](#42-desktop-analyzer-macos--windows--linux) |
| Read logs on the phone while testing, no computer involved | [4.3 In-app analyzer](#43-in-app-analyzer-mxlogger_analyzer_lib) |
| Your own viewer or upload pipeline in Dart | [4.4 Parsing in Dart](#44-parsing-in-dart) |

## 4.1 Where the files are

- **Directory**: `logger.diskcachePath`, i.e. `directory/nameSpace`. With the default directory that is `<Library>/com.mxlog.LoggerCache/<nameSpace>` on iOS and `<filesDir>/com.mxlog.LoggerCache/<nameSpace>` (`/data/data/<package>/files/...`) on Android.
- **File names** follow the storage policy (2.2), e.g. `2023-01-11_mxlog.mx`. The `error.txt` next to them (2.7) is plain text and needs no parser.
- **Listing from Dart**: `logger.logFiles` returns `MXFileEntity(name, size)`; the full path is `"${logger.diskcachePath}/${file.name}"`.

Getting the files onto a computer:

- **iOS device**: Xcode > Window > Devices and Simulators > select the device and the app > ⚙︎ > *Download Container…*. Right-click the `.xcappdata` > *Show Package Contents* > `AppData/Library/com.mxlog.LoggerCache/<nameSpace>/`.
- **iOS Simulator**:

  ```bash
  open "$(xcrun simctl get_app_container booted <bundle id> data)/Library/com.mxlog.LoggerCache/<nameSpace>"
  ```

- **Android** (debuggable build; the directory is app-private):

  ```bash
  adb shell run-as <package> ls files/com.mxlog.LoggerCache/<nameSpace>
  adb exec-out run-as <package> cat files/com.mxlog.LoggerCache/<nameSpace>/2023-01-11_mxlog.mx > 2023-01-11_mxlog.mx
  ```

- **Release builds / real users**: the app has to hand the file out itself, for example share it with `share_plus` or upload it to your server, using the paths from `logFiles`. Files can be copied while the logger is still open; the in-app analyzer below reads the live directory the same way.

## 4.2 Desktop analyzer (macOS / Windows / Linux)

Download `mxlogger_analyzer` for your OS from [Releases](https://github.com/coder-dongjiayi/MXLogger/releases). The first run is a three-step wizard:

1. **Pick the file**: drag one or more `.mx` files onto the window, or click to browse.
2. **Decryption**: enter the `cryptKey` / `iv` the logger was created with. Leave both empty for unencrypted logs. If the key was rotated, add every pair; they are tried in the numbered checkbox order until one decodes the record. The values are remembered for next time.
3. **Import**: a real progress bar (bytes parsed, rows written), then the data page opens automatically.

On the data page the header shows total count, time span and file name; below it a clickable level-distribution bar plus DEBUG–FATAL chips, keyword search (all / message / tag / name) with a time-range filter, click `@name` or `#tag` on any card to filter by it, a syntax-colored JSON tree for JSON messages, fullscreen detail for one record (Esc closes), and export to `.txt` through the share button. Change file, change key and clear data live in the header menu.

If parsing fails the wizard drops back to step 2, which almost always means a wrong `cryptKey` / `iv`. Logs written before v2.0.0 with a key shorter than 16 bytes may not decode (see the note in 2.1).

Screenshots and the full feature list are in the repository [README](https://github.com/coder-dongjiayi/MXLogger#log-analyzer).

## 4.3 In-app analyzer (`mxlogger_analyzer_lib`)

The analyzer core is also a Flutter package. It mounts a draggable floating ball on the app's `Overlay`; a tap opens a bottom sheet that parses `diskcachePath` on demand, so testers can read logs on the device without a computer.

```yaml
dependencies:
  mxlogger_analyzer_lib: last
```

```dart
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

final navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,
  // Every decryption pair, tried in order. Pass [] for unencrypted logs.
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  // Sharing is wired by the host (share_plus, your uploader, ...).
  // Returning false falls back to copying to the clipboard.
  onShare: (MXShareRequest request) async => false,
);

MXAnalyzer.dismiss(); // removes the ball and releases the database
```

It is a debugging tool: guard it behind a debug flag rather than shipping it to end users. Full API and mobile layout notes: [mxlogger_analyzer_lib README](https://github.com/coder-dongjiayi/MXLogger/blob/main/mxlogger_analyzer/mxlogger_analyzer_lib/README.md).

## 4.4 Parsing in Dart

`MXLogger.selectLogmsg` (2.8) decodes one file into a `List<Map<String, dynamic>>` with the same fields the analyzers display. Use it when you want your own UI, or to convert logs to JSON / text before uploading. It is synchronous FFI, so run it in an isolate; `log_viewer_page.dart` in the example is a complete reference.

# Example

`example/` is a complete demo app covering every API in this document: initialization, all five levels, loggerToken-based writes for modularized apps, storage policies, the file list, the log viewer and parsing, and destruction.

```bash
cd example && flutter run
```

# License

BSD 3-Clause, see [LICENSE](LICENSE).
