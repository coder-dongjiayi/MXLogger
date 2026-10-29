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
refresh the current file identity/capacity/committed length, append a complete
record, and publish its length last. Readers copy only committed bytes under a
shared directory lock and decode outside it. Shared-to-exclusive lock upgrades
and recursive acquisition of a directory lock are intentionally unsupported.
The `.mx` format is unchanged; no MMKV metadata/CRC format is introduced.

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
and remove-before-all preserve active files; explicit remove-all deletes them,
and the next append recreates them. Process termination releases leases through
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
