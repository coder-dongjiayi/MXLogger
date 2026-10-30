# Core native tests

The same C++ tests run on macOS and Windows through CMake/CTest. Tests are opt-in;
normal library consumers do not build them. Native macOS and Windows run the
same process tests using independent executables and pipe barriers. The other
platforms retain their existing file protocol and skip the process suite.

On macOS (run from the repository root):

```sh
cmake -S Core -B build/core-debug -DMXLOGGER_BUILD_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build build/core-debug --parallel
ctest --test-dir build/core-debug --output-on-failure --no-tests=error
```

Use a separate build directory and `-DCMAKE_BUILD_TYPE=Release` to verify Release.
The existing `bash Core/tests/run_tests.sh` and its sanitizer options still work.

On Windows with Visual Studio's Desktop development with C++ workload and CMake:

```powershell
cmake -S Core -B build/windows-core -A x64 -DMXLOGGER_BUILD_TESTS=ON
cmake --build build/windows-core --config Debug --parallel
ctest --test-dir build/windows-core -C Debug --output-on-failure --no-tests=error
```

Repeat the build and test commands with `Release`. Tests run in the build tree,
reset their own `mxtest_tmp` directory and retain it for troubleshooting. The test
runner returns failure if assertions fail, an exception escapes a case, or no
cases are registered. CTest also fails if no tests are found.

`.github/workflows/verify-logger.yml` runs MSVC x64 Debug and Release on Windows
only when manually dispatched; pushes and pull requests do not trigger it. From
a Mac, push the changes, open GitHub Actions, select `verify-logger`, then choose
**Run workflow** and the branch to verify. The workflow must first be present in
the repository's default branch for manual dispatch. Logs and JUnit results are
retained as separate artifacts for each configuration.

Windows regression cases cover Unicode paths and filenames, drive roots and both
path separators, mapping growth, reopening, encrypted read/write, deletion and
recreation, expiry, and multithreaded logging. Windows `long` remains 32 bits:
the legacy `dir_size()` result saturates at `LONG_MAX`, while cleanup uses 64-bit
size accounting. This does not extend the existing Dart FFI's 32-bit size API.

## Process protocol

`mxlogger_file.hpp` owns native files and mapped views. Windows uses UTF-16 paths,
`CreateFileW` with explicit sharing, and `LockFileEx`; macOS uses POSIX files and
`flock`. `mxlogger_interprocess.hpp` coordinates both platforms. All participating
processes must use this protocol, matching encryption settings and an accessible
shared local directory. Existing mobile file access remains single-process.

Writers acquire the logger's thread mutex, then the directory's exclusive lock,
refresh the open file's capacity/committed length, append a complete
record, and publish its length last. Readers copy only committed bytes under a
shared directory lock and decode outside it. Shared-to-exclusive lock upgrades
and recursive acquisition of a directory lock are intentionally unsupported.
The `.mx` format is unchanged; no MMKV metadata/CRC format is introduced.
Writes do not stat the path to detect external deletion or replacement. POSIX
loggers continue writing through their existing fd/mapping after an external
unlink; only reopening a logger creates a visible file again. Desktop recovery
queries the open fd once to synchronize capacity after another writer grows it.

Windows can retain a view under a separate byte-2 mapping lease. A competing
transaction requests background eviction; a 500 ms timeout also bounds retention
when notifications are unavailable. Contention briefly switches to transient
views. Read snapshots release their views before unlocking. All exclusive
directory transactions participate, including cleanup and non-caching writers.

Windows explicitly maintains mapped-file mtime. The first append of each wall-
clock second publishes mtime before committing the record; later appends in that
second defer the final tick until flush, view release or close. Process termination
therefore preserves the cleanup second even without a final callback. Timestamp
state resets on file reopen; cross-second clock rollback and update failures force
a new publish. This does not change the record format or power-loss durability.
The portable `test_write_time.cpp` suite checks the policy with deterministic
FILETIME ticks, including failure/retry and same-tick writes. Windows integration
checks close/flush expiration timestamps and killed-writer cleanup.

The persistent `.mxlogger.lock` is never a log or part of the size budget, and
must never be deleted while loggers exist. On Windows, byte zero coordinates
transactions. Separate shared byte-range leases represent active OS file IDs,
independent of data handles. Hash collisions conservatively preserve extra files
during cleanup. macOS keeps its existing data-fd shared leases. Age/size cleanup
and both remove-before-all and remove-all preserve active files. The mobile
backends also retain their own current file during all cleanup operations.
Process termination releases leases through
the OS; there are no PID files or persistent process registrations to repair.

The process suite covers stale state/growth, concurrent plain and encrypted
appends, a single header, snapshot barriers, Unicode worker arguments, cleanup,
explicit deletion, killed writers, independent directories, and lock failures.
The Windows-only foreign-view test deliberately retains a view outside this
protocol: native expansion may succeed or report a resize/mapping error, but
existing records must survive and writing must recover after the view is gone.
These checks cover process termination, not power-loss durability. Actual MSVC
execution still needs the manually triggered Windows CI; a macOS pass alone does
not validate the Windows backend.

## Public API coverage

API entry coverage is checked against the published declarations, including
overloads, deprecated forwarding methods, and property getters/setters:

| Layer | Inventory | Execution evidence |
| --- | --- | --- |
| C++ Core / Windows native SDK | 28 entries in `mxlogger.hpp` and `mxlogger_util.hpp` | LLVM function counters from the Core tests |
| iOS / macOS Objective-C API, imported by Swift | 57 entries in `MXLogger.h` | LLVM function counters; explicit XCTest assertions for three compiler-synthesized accessors |
| Android Java API | 37 entries in `MXLogger.java` | JaCoCo method counters against real host JNI/Core |
| Flutter native Dart API and models | 55 entries | First executable LCOV line per public method/getter |

These counts describe the current declarations, not a fixed denominator. The
checker discovers the inventory again on each run. Public Dart fields and
compiler-generated enum members are not method entries; enum values and model
fields are also asserted in the existing tests. Web remains a placeholder with
its own tests, not a native Core implementation.

**100% API entry execution does not mean 100% source lines, branches, input
combinations, or operating-system failure paths.** For example, executing the
Flutter `selectLogfiles` method on macOS only proves its non-iOS branch. Native
Apple tests exercise the actual file-list API separately; Flutter's mobile bridge
and lifecycle paths still require mobile integration tests. Windows-specific
runtime behavior must pass MSVC/Windows CI.

Regression assertions cover defaults, configuration readback, every constructor
overload, all log levels, headers, plain/encrypted readback, wrong keys, metadata,
cleanup preserving active files, shared instances, destruction, and recovery from
an unwritable path. In particular, `delete_namespace(nullptr)` must not crash or
destroy another logger, and Apple `enable` must agree with the Core default.

Run the Android contract tests on the host with JDK 17 and an installed Android
SDK (the same five contract cases also run under Android instrumentation):

```sh
bash scripts/verify_android_api_host.sh
# Physical device/emulator: authorize installation on the device first.
cd platform/Android/MXLogger
bash gradlew :mxlogger:connectedDefaultCppDebugAndroidTest
```

The host tests replace only Android OS services (`Context`/`Looper`) using AGP's
mockable android.jar. JNI registration, the Java SDK, Core, encryption, and file
read/write all run for real. This does not replace the Android device tests. The
manual `verify-logger` workflow runs the host contract tests before packaging,
and retains JaCoCo XML/HTML with the Android test logs.

Run `bash scripts/verify_ios_api.sh` with a compatible installed Xcode simulator
runtime to execute the Apple API tests including iOS background cleanup. The
script selects a compatible iPhone/runtime pair, creates a temporary simulator,
and shuts down/deletes only that device when finished. The Apple CI job runs this
check and retains its `.xcresult` coverage and test summary. macOS-only lifecycle
behavior is tested separately by `platform/iOS/MXLogger/tests/run_tests.sh`.

For the full local entry report, collect instrumented Core/Apple tests and Dart
coverage in separate test build directories. Instrumentation is opt-in and never
part of the distributed library:

```sh
cmake -S Core -B build/api-coverage/core -DMXLOGGER_BUILD_TESTS=ON \
  -DCMAKE_BUILD_TYPE=Debug \
  '-DCMAKE_CXX_FLAGS=-fprofile-instr-generate -fcoverage-mapping' \
  '-DCMAKE_C_FLAGS=-fprofile-instr-generate -fcoverage-mapping'
cmake --build build/api-coverage/core --parallel
mkdir -p build/api-coverage/core/profiles
rm -f build/api-coverage/core/profiles/*.profraw
LLVM_PROFILE_FILE="$PWD/build/api-coverage/core/profiles/%p.profraw" \
  ctest --test-dir build/api-coverage/core --output-on-failure --no-tests=error
xcrun llvm-profdata merge -sparse build/api-coverage/core/profiles/*.profraw \
  -o build/api-coverage/core/coverage.profdata
xcrun llvm-cov export build/api-coverage/core/tests/mxlogger_tests \
  -instr-profile=build/api-coverage/core/coverage.profdata \
  > build/api-coverage/core/coverage.json

mkdir -p build/api-coverage
COVERAGE=1 MXLOGGER_APPLE_TEST_BUILD_DIR="$PWD/build/api-coverage/apple" \
  bash platform/iOS/MXLogger/tests/run_tests.sh > build/api-coverage/apple.log 2>&1
(cd platform/flutter_mxlogger && bash test/native/build_test_dylib.sh && \
  flutter test --coverage --coverage-path=../../build/api-coverage/flutter.info)
bash scripts/verify_android_api_host.sh

python3 scripts/check_api_coverage.py \
  --core-json build/api-coverage/core/coverage.json \
  --apple-json build/api-coverage/apple/coverage/coverage.json \
  --apple-log build/api-coverage/apple.log \
  --java-xml platform/Android/MXLogger/mxlogger/build/reports/jacoco/apiCoverageReport/apiCoverageReport.xml \
  --dart-lcov build/api-coverage/flutter.info \
  --output build/api-coverage/summary.json
```

The checker exits nonzero for missing entries and writes both JSON and HTML with
the API inventory and evidence used. Keep the raw LLVM, JaCoCo and LCOV reports
when inspecting uncovered lines or branches; the entry report is not a substitute
for those reports.
