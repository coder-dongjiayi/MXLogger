
# MXLogger for Flutter Change Log
# v2.3.1/2026-10-30
* Update description.
# v2.3.0/2026-10-30
* Add Windows 10/11 x64 support through precompiled `mxlogger_ffi.dll` binaries. Flutter bundles the Debug DLL for Debug builds and the Release DLL for Profile/Release builds; consuming apps do not compile Core or require NuGet installation.
* Add `MXLogger.coreVersion()` to query the linked C++ Core version without initializing a logger. Show the Core version in the demos.
* On Windows, resolve the default log directory through the DLL as `%LOCALAPPDATA%/MXLogger/<executable stem>/<nameSpace>`. Like macOS, Windows uses explicit cleanup through `removeExpireData()` rather than mobile background cleanup.
* Share the pure C++ FFI bridge between Android and Windows, with common C declarations and pointer-sized logger handles.
* Make native file-list buffers use the paired `flutter_mxlogger_free_logfiles` function instead of Dart-side frees. Keep native strings and parsed-log buffers paired with `free_string` and `free_logmsg`, and release file-list/parsed-log results in `finally` blocks so decoding failures also clean up native memory.
* **Native dependency requirement:** use the matching 2.3.0 Android and Apple native SDKs and Windows DLLs. The new file-list release function is unavailable in older bridges; applications overriding native dependency versions must update them together with this package.
* Preserve active mapped log files during cleanup and improve desktop Core write performance by reducing repeated filesystem metadata checks and mapping growth overhead.
* Add the Flutter Windows feature demo, including encrypted log viewing, file browsing, explicit cleanup, Core version display, and concurrent-isolate writes. CI tests Debug/Release DLL loading, UTF-8 paths, allocation/free pairs, and relocated application bundles, and provides a complete interactive Windows Release Demo.

# v2.2.0/2026-10-26
* Complete the Flutter macOS demo with desktop layout, settings dialogs, manual cleanup guidance, a Finder entry, local-source launch commands, and UI regression previews.
* Add macOS support, including the Flutter plugin, CocoaPods, SwiftPM, and cooperative multi-process access to a shared log directory.
* Share the Apple plugin implementation through `darwin/` using Flutter 3.7's `sharedDarwinSource` layout.
* On macOS, use `Application Support/<bundle-id>/MXLogger` by default (fall back to the process name if no bundle ID is available). Cleanup is explicit through `removeExpireData()`; `shouldRemoveExpiredDataWhenEnterBackground` has no effect.
* Add reproducible local-source macOS regression checks and CI for native Apple APIs, Flutter CocoaPods/SwiftPM Debug and Release builds, and Android native compilation across four ABIs.
* Align the Flutter package and native CocoaPods, SwiftPM, and Android dependencies to 2.2.0.
* Raise the minimum supported Flutter version to 3.7.0 and Dart SDK to 2.19.0.
* Migrate the native SwiftPM dependency to `https://github.com/coder-dongjiayi/mxlogger-spm.git`.

# v2.1.0/2026-09-24
* Support the Swift Package Manager
* **Breaking** Rename `MXStoragePolicyType` values to lowerCamelCase to satisfy `constant_identifier_names` lint: `yyyy_MM_dd` → `yyyyMMdd`, `yyyy_MM_dd_HH` → `yyyyMMddHH`, `yyyy_ww` → `yyyyWw`, `yyyy_MM` → `yyyyMM`. The strings passed to the native layer are unchanged, so existing log files and file naming are unaffected.
* Rename the `loggerKey` concept to `loggerToken` — the old name was easy to confuse with the encryption `cryptKey`. New APIs: `loggerToken` getter, `getLoggerToken()`, `logLoggerToken(...)`, `destroyWithLoggerToken(...)`.
* **Deprecated** `loggerKey`, `getLoggerKey()`, `logLoggerKey(...)` and `destroyWithLoggerKey(...)`. They forward to the new APIs and keep working, but **will be removed in a future release** — please migrate.
* The parameter of `debugLog` / `infoLog` / `warnLog` / `errorLog` / `fatalLog` is now named `loggerToken`; the value it takes is unchanged.
* Requires the matching MXLogger native libraries (iOS / Android), which expose the same `loggerToken` APIs and deprecate the `loggerKey` ones.
# v2.0.0/2026-08-22
Keep up with MXLogger  native lib v2.0.0 on Android/iOS.
* Fix incorrect week number in `yyyy_ww` file naming when a week spans the new year.
* Fix a memory leak in the Android native bridge.
* Fix a low-probability crash caused by mmap mapping.
* Fix a dangling pointer that could be dereferenced after `destroy()` on Dart/iOS.
* Fix `key`/`iv` shorter than 16 bytes causing the analyzer to fail to decode log files.
* **Breaking** Unify all FFI signatures to fixed-width `Int32` to avoid width mismatch across platforms.
# v1.2.15/2025-09-05
* Support 16 KB page sizes on Android。native lib v1.2.15 Android.
# v1.2.14/2024-10-31
* Fix Fixed a bug where files were overwritten。 native lib v1.2.14.
# v1.2.13+2/2024-07-10
* Change the folder permission to 0777 for local export.
# v1.2.13+1/2024-05-27
* Fix bug. 
* Annotation flatDir。In order to fix the android side of the compilation error
# v1.2.13/2024-05-21
* Add `flutter_mxlogger_web.dart`. Only the method name is not implemented.
* Compatible with web side compilation
# v1.2.12/2024-04-26
* Keep up with MXLogger  native lib v1.2.12 on Android.
* Fix jin error.
# v1.2.11+1/2024-04-08
* Add `writeFail` method.
* You can write fail info when `log` return value not 0.
* `mxlogger.diskcacheErrorPath` is error path. You can use this path to manipulate file information
# v1.2.11/2024-3-27
* Log write Add return value。0 success,otherwise field.
* Add `errorDesc` get log error.
* Keep up with MXLogger  native lib v1.2.11.
# v1.2.10+3/2024-02-18
* Compatible Gradle 8.0 on Android. AndroidManifest.xml add package. fix package is com.coderdjy.mxlogger.
* 
# v1.2.10+2/2024-02-18
* Compatible Gradle 8.0 on Android. AndroidManifest.xml add package.
# v1.2.10+1/2024-02-18
* Compatible Gradle 8.0 on Android.
# v1.2.10/2023-12-02
* Keep up with MXLogger  native lib v1.2.10.
* Remove logger_key field in console
# v1.2.9/2023-11-13
* Keep up with MXLogger  native lib v1.2.9.
* Fix memory leak When setting setConsoleEnable is ture.
# v1.2.8/2023-08-14
*  Keep up with MXLogger  native lib v1.2.8.
* Remove shouldRemoveExpiredDataWhenTerminate on ios native.
* Replace fileLevel with the level field.
# v1.2.7+1/2023-06-21
* Fix bug
# v1.2.7/2023-06-20
* Adapter armv7 on Android. Add  annotation on iOS. Keep up with MXLogger  native lib v1.2.7
# v1.2.6/2023-06-03
* fix bug. maybe crash when Clean up expired files . Keep up with MXLogger  native lib v1.2.6
# v1.2.5+6/2023-05-06
* Update Flutter dependencies, set Flutter >=3.3.0 and Dart to >=2.18.0 <4.0.0
# v1.2.5+5/2023-05-05
* Format
# v1.2.5+4/2023-05-05
* Resolve the problem of using class methods in plug-ins that are not valid on Android
# v1.2.5+3/2023-05-05
* Keep up with MXLogger native lib v1.2.5.3 on Android
* Fix crash on native Android.
# v1.2.5/2023-03-06
* Keep up with MXLogger native lib v1.2.5.
* Add removeBeforeAllData() method.
# v1.2.4/2023-02-10
* Keep up with MXLogger native lib v1.2.4.
* Use "🟩","🟦","🟨","🟥","❌ emoji for 'DEBUG','INFO','WARN','ERROR','FATAL' on console.
# v1.2.3/2023-01-31
* Keep up with MXLogger native lib v1.2.3.
* fix bug
* formatting console json
# v1.2.2/2023-01-16
* Keep up with MXLogger native lib v1.2.2.
* Add logFiles method.
* Use `2023-01-02w_filename.mx` named file when storagePolicy is yyyy_ww.
* Change default name is log
# v1.2.1/2023-01-12
* Keep up with MXLogger native lib v1.2.1
* StoragePolicy arg use enum
* Fix bugs

# v1.2.0+1/2023-01-03
* Fixed bugs on android

# v1.2.0/2022-12-28
* Keep up with MXLogger native lib v1.2.0
* Add fileHeader

# v1.1.3/2022-10-13

* Keep up with MXLogger native lib v1.1.2
* Android remove unnecessary dependencies

# v1.1.2/ 2022-10-10

* fix bug

## v1.1.1 / 2022-10-09

* Android Change the package name.

## v1.1.0 / 2022-10-09
* Keep up with MXLogger native lib v1.1.0
* Logs can be written using loggerKey



