# MXLogger Flutter example

The example uses the plugin from the parent directory. The plugin requires
Flutter 3.7+, while this example's dependencies require Dart 3.8+.

On macOS, run from this directory:

```bash
flutter pub get
flutter run -d macos
```

The native `MXLogger` / `MXLoggerCore` pods or `mxlogger-spm` package must be
available at version 2.2.0. For CocoaPods development before publication, set
`MXLOGGER_LOCAL_NATIVE=1` to use the native sources from this checkout. When
Flutter's SwiftPM integration is enabled, its package dependency must instead
be resolved to a local `mxlogger-spm` checkout for unpublished builds.

The macOS tests exercise the registered MethodChannel, default and custom
directories, encrypted FFI writes and reads, logger tokens, reopening, explicit
cleanup, and writes from secondary isolates:

```bash
flutter test integration_test/macos_logger_test.dart -d macos
```

Flutter integration tests run in Debug. Verify Release AOT and FFI symbol
retention with the separate entrypoint:

```bash
flutter build macos --release -t integration_test/macos_release_smoke.dart
build/macos/Build/Products/Release/example.app/Contents/MacOS/example
```

The Release check prints `MXLOGGER_MACOS_RELEASE_SMOKE_OK` and exits with code 0
after an encrypted write/read round trip. Both checks remove their test logs.
Use a deployment target supported by your installed Xcode SDK for the Runner
and its dependencies; the plugin's declared macOS minimum is 10.14.

On macOS, `shouldRemoveExpiredDataWhenEnterBackground` has no effect. Call
`removeExpireData()` explicitly when your app wants to enforce its age and size
limits. Default logs are under `Application Support/<bundle-id>/MXLogger` (inside
the app container when sandboxing is enabled).

To run all checks against unpublished local native sources, use
`python3 scripts/verify_macos_support.py` from the repository root. It creates
isolated CocoaPods and SwiftPM fixtures and adjusts only their deployment targets
to the installed Xcode SDK. See the main repository's
[verification instructions](../../README.md#macos-regression-checks-and-release-preparation).
