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
macOS、iOS 和 Android 的映射策略保持原样。共享目录的所有进程应一起更新到本次构建，避免混用不同的协调协议。

可以在同一台 Windows 机器上比较缓存开关下的真实写入耗时：

```powershell
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Release -Benchmark
```

脚本使用同一个 exe、相同 `log()` 循环分别执行明文 / AES 各 100,000 条，并在计时结束后
验证记录数量和顺序。`benchmark/transient/` 使用诊断变量 `MXLOGGER_WINDOWS_MAPPING_CACHE=0` 关闭映射复用，
`benchmark/cached/` 开启复用；两组都保留跨进程锁、新的扩容策略和逐条文件时间更新。
因此这个对照隔离的是映射复用的收益，不能作为与历史版本整体性能差异的精确对照。
脚本结束后恢复环境变量，正常运行 Demo 默认开启复用。

## 写入分段诊断

验证脚本会额外构建控制台工具 `MXLoggerProfile.exe`，它链接独立的
`MXLoggerCoreProfile`。普通 GUI 和正式 Benchmark 链接的 Core 不含采样代码；
诊断不改变加锁、逐条修改时间更新、加密或提交逻辑。Release CI 会自动运行诊断，
Debug 也会编译诊断工具并验证统计器。

从仓库根目录构建、验证并运行完整评测：

```powershell
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Release -ProfileWrites
```

下载并**解压整个 ZIP** 后，Debug / Release 的 `MXLoggerProfile.exe` 均支持直接双击：

- 无参数自动诊断明文 / AES 各 100,000 条，不依赖 PowerShell。
- 窗口先显示运行状态和报告位置，写入期间不刷新逐条进度，结束后显示耗时及分段结果。
- 报告默认保存在 `%LOCALAPPDATA%\MXLoggerDemo\Profile\single-...\profile.json` 和 `profile.txt`。
- 资源管理器双击创建的控制台会在成功或失败后保留，按 Enter 关闭；命令行 / CI 调用正常返回退出码。

完整 7 轮普通 / 诊断对照可双击包内 `Run-Performance-Test.cmd`。
它会显示预热、当前轮次及报告路径，结束或出错后保留窗口；缺少 PowerShell 7 时明确提示。
这些状态在各轮测试之间输出，不进入写入循环的计时。
也可在同一台 Windows 电脑的终端执行：

```powershell
pwsh -File .\profile_windows_demo.ps1
```

脚本默认使用脚本所在目录的两个 exe；可通过 `-ExecutableDirectory` 指定构建产物目录，
通过 `-ReportDirectory` 指定报告及临时日志的父目录（应与之前测试使用同一磁盘）。
每次建立独立的 `run-时间戳/`，不覆盖原有报告或使用 Demo 的日志目录。
默认每个 exe 预热一轮，然后交替运行普通 / 诊断程序各 7 轮，每轮各写入
100,000 条明文和 AES 日志。普通程序仍使用现有 `--benchmark` 循环。
控制台、进度刷新、初始化、显式 flush、读取校验和报告输出均不进入写入计时；
每轮计时后检查文件头、记录数量、消息顺序及解密。

结果首先看 `summary.txt` / `summary.json`：普通版本的中位数、最小值和最大值，
诊断相对耗时差异，各阶段估算耗时排序，以及独立 API 微基准。
阶段包括消息构造、线程锁等待、元数据、FlatBuffers 构造与分配释放、AES、
目录锁获取 / 释放、缓存互斥锁等待、缓存协调 / 映射交接等待、文件打开 / 关闭、
映射检查 / 创建 / 解除、扩容、文件时间更新、数据复制和其他开销。

默认每 64 条抽样一次，并在各轮错开起点；恢复映射、打开关闭文件、映射与扩容、
实际交接等待等低频操作完整计时。嵌套阶段采用独占耗时，子阶段从父阶段扣除，
不会把缓存交接同时算作目录锁调用。所有计数在线程本地内存累积，仅统计计时循环
所在前台线程；后台 CPU 不加入占比，前台等待后台释放资源的时间会被计入。
`cache_hits`、`cache_misses`、`mapping_handoffs`、`ready_set_events` 和 `ready_reused`
可检查实际路径和事件复用是否生效。初始化和结束后的 flush / 校验不进入这些统计。

`profile.json` 保留每段调用数、抽样 / 完整计时数、实际采集耗时和估算值。
完整计时部分直接采用，抽样部分按记录采样比例外推；未采到的条件分支显示 `null`。
估算占比不强制归一到 100%，不同轮次的阶段中位数也不一定加总为总耗时中位数。
时钟调用成本单列，未机械扣减。诊断耗时不能作为正式 Benchmark 成绩；
`other` 还包含未分段代码与部分统计记账开销，不能直接视为可消除的业务开销。
如果诊断比普通版本慢超过 5%，先降低采样频率再复测：

```powershell
pwsh -File .\profile_windows_demo.ps1 -SampleStride 256
```

单次诊断可运行 `MXLoggerProfile.exe --report-dir .\single-profile`。
独立 API 复核可运行 `MXLoggerProfile.exe --microbench --report-dir .\api-profile`：
在同盘临时文件上测量 100,000 次无竞争锁获取 / 释放，以及修改时间更新。
微基准使用未映射的独立文件，其耗时用于复核热点，不能直接从真实日志耗时中相减。
报告目录保留测试数据，可在评测结束后自行删除。

本轮先评测单进程单线程，定位约 2.95 秒耗时；确认热点后再增加双进程共享 / 独立目录对照。
CI 用来验证编译与结果完整性，性能对比应在同一台本地 Windows 电脑上完成。
Mac 的诊断目标仅验证统计器和共用写入路径，报告明确标记 `macos-model-only`。

## 自动验证与 CI 产物

安装 PowerShell 7 后，在 Windows 执行：

```powershell
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Debug
pwsh -File scripts/verify_windows_demo.ps1 -Configuration Release
```

脚本构建实际 GUI exe，运行 `--self-test --report-dir <目录>`，再安装并生成 zip。
自测先执行共用操作的明文/加密回归，再创建真实窗口、点击原生控件，覆盖设置、浏览、筛选、
线程/进程、性能、清理、重建及双语，并生成窗口 PNG。自测使用独立的含中文与空格目录，不清理用户日志。
自动自测缩小写入数量：每线程 32 条、每进程 64 条、性能 500 条；共用模型另测每进程 128 条。
结果在 `build/windows-native-demo/<Debug|Release>/self-test/`，包含 `model/report.json`、`ui-report.txt` 和截图。

GitHub Actions 的 `verify-logger` **仅手动触发**。每次运行仍验证 Windows Debug/Release、Apple 和 Android；
Windows 会额外构建、自测并上传此 Demo，同时运行上述 100,000 条对照测试。
耗时、吞吐量和倍数在日志及 `benchmark/comparison.json` 中，不以固定耗时作为 CI 成败阈值。
下载 `windows-demo-<配置>` 中的 zip，解压运行 `MXLoggerDemo.exe`；包中也包含诊断工具及脚本。
Release 的分段评测报告位于 `windows-demo-Release-logs` 中的 `profile/run-*/`。
两种配置都会额外验证诊断 exe 无参数启动，启动输出与单轮结果见 `profile-startup.log`。
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

`verify_windows_demo.ps1` builds, runs shared model checks and real window/control smoke checks, saves reports/PNGs,
and produces a zip. Manual `verify-logger` CI runs this for Debug and Release alongside all other platforms.
On macOS only the shared action model runs; native Windows compilation/UI verification requires Windows or Windows CI.

Windows reuses mappings while it holds a separate interprocess lock, with background eviction for conflicting
writers/cleanup. Actual contention temporarily switches to transient views; idle peer loggers do not disable caching.
Retention is bounded to 500 ms,
with a 250 ms cooldown after contention. All cooperating writers should upgrade together; the log format and other
platforms' mapping behavior are unchanged. The benchmark has no per-record progress/cancellation polling or UI timer;
it reports total write time before manually loading previews. Pass `-Benchmark` to compare cache off/on using the same
executable and verify 100,000 plaintext/AES records per case. Reports are under `benchmark/` in the build directory.
