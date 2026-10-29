# MXLogger Windows Native Demo

原生 Win32 + C++17 桌面示例，直接链接本仓库的 Core，不依赖 Flutter、Qt 或 MFC。
界面使用现有 Demo 的 Logo 和紫色状态卡，支持中英文切换、缩放与窗口滚动。

## Windows 上构建和运行

安装 Visual Studio 2022 或更新版本的「使用 C++ 的桌面开发」（包含 Windows SDK），以及 CMake 3.20+。
在仓库根目录执行：

```powershell
cmake -S platform/Windows/MXLoggerDemo -B build/windows-demo -A x64
cmake --build build/windows-demo --config Debug --parallel
.\build\windows-demo\bin\Debug\MXLoggerDemo.exe
```

Release 将上述 `Debug` 换成 `Release`。CMake 生成的 `MXLoggerDemo.sln` 也可在 Visual Studio 中打开。
示例静态链接 Core 和 MSVC CRT，打包的 exe 无需另外安装 VC++ 运行库。
当前交付目标是 Windows 10/11 x64；ARM64 不在这次 CI 验证范围内。

## 功能

- 默认命名空间 `com.djy.mxlogger`、按小时文件、AES-CFB-128、保留 7 天、上限 10 MB。
- 默认目录 `%LOCALAPPDATA%\MXLoggerDemo\Logs`；在「初始化配置」中修改目录、命名空间、文件名、策略、Key/IV，再应用。
- 五级日志、网络 JSON、Token 写入；运行时写入开关、最低等级、保留时间、大小限制和 Debug 控制台开关。
- 四线程共 4,000 条、两个独立进程共 2,000 条；写入后实际读取文件，校验数量和各线程/进程内部顺序。
- 100,000 条直接写入性能测试：关闭控制台和 UI 定时刷新，循环内不更新进度或轮询取消；写完显示总耗时和吞吐量。计时不含 flush 和读取，日志预览需手动刷新。
- 文件列表、最新 1,000 条日志预览、等级/关键词筛选、完整记录详情；复制路径/Token、打开目录、错误详情。
- 手动清理过期、仅保留当前、删除全部。保留时长和大小在点击清理时生效，无后台清理开关。

耗时操作在后台执行；并发测试可取消，性能测试等待整批写完。关闭窗口会等待工作结束并回收演示子进程。
Release 控制台开关置灰。Debug 控制台输出沿用 Core 的 stdout；需要查看时，从带输出重定向的终端启动。
配置只保存在当前进程中，默认 Key/IV 是公开的演示参数。切换密钥请使用新命名空间；
Demo 会检查已有文件的解码状态，避免以不匹配的参数继续写入。
启动多个 Demo 可指向同一目录演示共享写入；请保持命名空间、文件名、策略和加密参数一致。

## Windows 写入性能

Core 的 Windows 路径会在持有映射保护锁时复用文件句柄和映射，减少逐条打开、映射和关闭。
映射由独立的跨进程锁保护；其他写入或清理者通知后台线程释放它，拿到锁后才继续操作。
有实际锁竞争时会短暂使用逐次释放的路径，避免每条日志都交接缓存；另一个 Demo 仅处于空闲状态不会一直禁用缓存。
是否可以复用由实际映射锁竞争决定，不依赖日志频率。通知不可达时，后台线程也会在
500 ms 的租期结束后释放映射；竞争后暂缓缓存 250 ms，这些时间只影响复用策略。
首次容量为 64 KiB，扩容时最多预留 1 MiB；文件长度可能大于实际日志数据，四字节提交长度及 `.mx` 格式保持不变。
Windows 的映射写入可能不会自动更新文件修改时间，因此需要显式维护，见
[微软文件映射说明](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-createfilemappinga#remarks)。
目前清理按秒比较时间：每个文件句柄首次写入、每个新的系统时间秒都会在提交记录前更新修改时间，
同秒内其余写入合并更新。`flush`、解除映射（含扩容）、交接和正常关闭时，补齐最后一次成功写入的时间。
进程被强制结束时，即使没机会补齐亚秒时间，已提交数据所在的秒也已发布；修改时间不等同于同步刷盘保证。
时间回拨跨秒或句柄重新打开时重新更新时间；失败保留待补状态并在后续写入重试。
未保留映射或存在持续争抢时，句柄频繁交接，合并空间也相应减少。
macOS、iOS 和 Android 的映射策略保持原样。共享目录的所有进程应一起更新到本次构建，避免混用不同的协调协议。

在 Demo 中运行 100,000 条性能测试，写完后查看总耗时与吞吐量。
计时不含显式 flush 和读取，循环内不刷新进度；对比时保持同一台机器、日志目录及加密配置。

## 自动验证与 CI 产物

安装 PowerShell 7 后，在 Windows 执行：

```powershell
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Debug
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Release
```

脚本构建实际 GUI exe，运行 `--self-test --report-dir <目录>`。
自测先执行共用操作的明文/加密回归，再创建真实窗口、点击原生控件，覆盖设置、浏览、筛选、
线程/进程、性能、清理、重建及双语，并生成窗口 PNG。自测使用独立的含中文与空格目录，不清理用户日志。
自动自测缩小写入数量：每线程 32 条、每进程 64 条、性能 500 条；共用模型另测每进程 128 条。
结果在 `build/windows-native-demo/<Debug|Release>/self-test/`，包含 `model/report.json`、`ui-report.txt` 和截图。

GitHub Actions 的 `verify-logger` **仅手动触发**。每次运行仍验证 Windows Debug/Release、Apple 和 Android；
全部平台验证通过后，单独的 Release 阶段直接上传 `MXLoggerDemo.exe`，不生成 Debug 包或 zip。
自测保留缩小规模的性能按钮检查；运行日志及截图位于对应的 `-logs` 产物。
安装文件使用 `upload-artifact@v7` 的 `archive: false`，下载得到原始 exe。
这验证原生 Windows Demo，Flutter Windows / FFI DLL 将在后续阶段接入。

## 在 Mac 上开发

界面代码可在 Mac 编辑，Windows 编译、窗口运行与打包交给手动 CI。
共用的配置、日志、清理和多进程操作可以在 Mac 实际运行：

```bash
cmake -S platform/Windows/MXLoggerDemo -B build/windows-demo-model -DCMAKE_BUILD_TYPE=Debug
cmake --build build/windows-demo-model --parallel
ctest --test-dir build/windows-demo-model --output-on-failure
```

Mac 目标 `MXLoggerDemoModelCheck` 不包含 Win32 窗口；其通过不能替代 Windows CI 的编译与窗口检查。

---

Native Win32/C++17 demo, linked to this checkout's Core. Build the GUI on Windows with the commands above;
no Flutter/Qt/MFC or separately installed MSVC runtime is required. Defaults match the other native demos.
Use **Configuration** to choose a log directory, namespace, file policy and AES parameters. **Actions** provides
logging/settings, validated thread/process runs, benchmarking, cleanup and instance rebuilding. The right pane
lists files and the latest 1,000 records, with level/search filters and full record details. Settings are session-only.
The default key/IV are public demo values; choose a new namespace when changing keys.

`verify_windows_demo.ps1` builds, runs shared model checks and real window/control smoke checks, and saves reports/PNGs.
Manual `verify-logger` CI verifies Debug and Release alongside all other platforms, then uploads only the Release EXE
after every verification job passes. It does not create a separate ZIP package.
On macOS only the shared action model runs; native Windows compilation/UI verification requires Windows or Windows CI.

Windows reuses mappings while it holds a separate interprocess lock, with background eviction for conflicting
writers/cleanup. Actual contention temporarily switches to transient views; idle peer loggers do not disable caching.
Retention is bounded to 500 ms,
with a 250 ms cooldown after contention. All cooperating writers should upgrade together; the log format and other
platforms' mapping behavior are unchanged. The benchmark has no per-record progress/cancellation polling or UI timer;
it reports total write time before manually loading previews. Windows writes coalesce modification
time updates within a wall-clock second and publish the last committed tick on flush/view release/close. The first
append in each new second publishes before committing, preserving second-based expiration after process termination.
