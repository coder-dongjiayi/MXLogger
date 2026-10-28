# MXLogger Apple framework

`MXLogger.xcodeproj` builds the same Objective-C API for iOS and native macOS.
The framework depends on `../../../Core/MXLoggerCore.xcodeproj` and uses C++17.
The CocoaPods distribution declares iOS 9.0 and macOS 10.13. The checked-in Xcode
projects use an iOS build baseline of 15.0; individual targets may select a higher version.

Run these commands from the main repository root:

```sh
xcodebuild -project platform/iOS/MXLogger/MXLogger.xcodeproj -scheme MXLogger \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/apple-framework 'ARCHS=arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build

xcodebuild -project platform/iOS/MXLogger/MXLogger.xcodeproj -scheme MXLogger \
  -destination 'platform=macOS' -derivedDataPath build/apple-framework \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 test
```

Choose a deployment target supported by the installed SDK. These commands use macOS 12
because Xcode 27 rejects lower targets. Its iOS SDK requires every project and target,
including the Core dependency, to use iOS 15.0 or later. The local Xcode settings do
not change the minimum versions declared by the distribution. macOS 10.13 API availability is checked
by compiling the C++ and Objective-C++ sources for `x86_64-apple-macos10.13` with
`-Werror=unguarded-availability -Werror=unguarded-availability-new`; it is not a runtime
test on an older Mac.

To run the native iPhone demo, open `platform/iOS/MXLoggerDemo/MXLoggerDemo.xcodeproj`, choose
the **MXLoggerDemo** scheme and your iPhone, then Run. `MXLoggerCore` is a static
library build scheme, not a runnable app. In Signing & Capabilities, select your
development team for the Demo, MXLogger framework and their test targets in both
Debug and Release. Changing only the app target does not update the dependency projects.
The unsigned CI builds below do not validate your local signing certificates or profiles.
To check the full device build without signing:

```sh
xcodebuild -project platform/iOS/MXLoggerDemo/MXLoggerDemo.xcodeproj -scheme MXLoggerDemo \
  -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build/ios-native-demo/Debug CODE_SIGNING_ALLOWED=NO build
```

`scripts/verify_macos_support.py` also builds the native iPhone Demo in Debug and
Release with the checked-in deployment targets, independently of the SDK overrides
used for CocoaPods/SwiftPM verification. These builds do not install or run on a device.

CocoaPods uses the root `MXLogger.podspec` and `MXLoggerCore.podspec`.
SwiftPM uses `spm/Package.swift`; `scripts/sync_spm_mirror.sh` assembles the distribution
for [mxlogger-spm](https://github.com/coder-dongjiayi/mxlogger-spm).
