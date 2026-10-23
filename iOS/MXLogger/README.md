# MXLogger Apple framework

`MXLogger.xcodeproj` builds the same Objective-C API for iOS and native macOS.
The framework depends on `../../Core/MXLoggerCore.xcodeproj` and uses C++17.
The declared deployment targets are iOS 9.0 and macOS 10.13.

Run these commands from the main repository root:

```sh
xcodebuild -project iOS/MXLogger/MXLogger.xcodeproj -scheme MXLogger \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/apple-framework 'ARCHS=arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build

xcodebuild -project iOS/MXLogger/MXLogger.xcodeproj -scheme MXLogger \
  -destination 'platform=macOS' -derivedDataPath build/apple-framework \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 test
```

Choose a deployment target supported by the installed SDK. These commands use macOS 12
because Xcode 27 rejects lower targets; iOS builds with that Xcode need an
`IPHONEOS_DEPLOYMENT_TARGET=15.0` override. These build overrides do not change the
minimum versions declared by the distribution. macOS 10.13 API availability is checked
by compiling the C++ and Objective-C++ sources for `x86_64-apple-macos10.13` with
`-Werror=unguarded-availability -Werror=unguarded-availability-new`; it is not a runtime
test on an older Mac.

CocoaPods uses the root `MXLogger.podspec` and `MXLoggerCore.podspec`.
SwiftPM uses `spm/Package.swift`; `scripts/sync_spm_mirror.sh` assembles the distribution
for [mxlogger-spm](https://github.com/coder-dongjiayi/mxlogger-spm).
