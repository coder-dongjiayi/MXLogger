# macOS 写入性能诊断（临时分支）

只用于定位原生 Release Demo 的 10 万条写入瓶颈。
本轮已移除桌面写入时的路径删除/替换检查及重复 `fstat`，macOS 每条写入只保留一次句柄容量查询。
诊断组的 `path_stat.calls` 应为 0，`file_info.calls` 应为写入条数。
清理接口统一保留正在使用的文件。
macOS 已采用 Windows 现有的桌面扩容策略：64 KiB 起步，随后倍增，每次常规扩容最多增加 1 MiB；
空闲容量不足时才扩容并重新映射。相比此前按页扩容，`resize` / `mapping` / `unmapping` 调用次数应明显下降。
iOS/Android 仍按页扩容；锁、加密、实际数据长度及提交顺序未改。
独立的 `profile-macos` GitHub Actions 只构建本工具，不运行 Windows、Android 或全平台回归。
支持手动触发，并仅对当前临时分支 `macos-test` 的诊断相关文件推送自动触发，便于首次运行，
无需先把诊断代码合入主分支。推送后在 Actions 查看 `profile-macos`，下载 `MXLoggerProfile-macOS.dmg`。
原有 `verify-logger` 未修改，仍只手动触发。
GitHub 页面上的手动按钮通常要求 workflow 已存在默认分支；首次推送运行注册后，
也可用已配置 GitHub CLI 执行 `gh workflow run profile-macos.yml --ref macos-test`。
如果改用另一个诊断分支，请同步修改 workflow 的 `push.branches`。

## 在待测 Mac 上运行

打开 DMG，把 `MXLoggerProfile.app` 拖到 Applications 或其他可写目录，双击应用，再点「运行 10 万条评测」。
这是 ad-hoc 签名、未经 Apple 公证的测试程序。程序为 Intel + Apple Silicon 通用版本；
最低系统版本取构建 SDK 支持的最低版本与 macOS 10.15 的较高者，详见报告的 build 信息。
如系统拦截启动，可在确认这是自己构建的程序后，到「系统设置 → 隐私与安全性」允许打开。

每组之间显示状态，10 万条写入循环内不刷新 UI。默认三轮，结束自动打开独立报告目录：

`~/Library/Application Support/MXLoggerProfile/Reports/<时间-随机标识>/`

请提供 **summary.json 和 summary.txt**。失败也会生成这两个文件，子目录中的 result.json / process.log 可排查具体错误。
测试使用专用日志目录；不删除或读取原有 Demo 日志。多组测试会占用数百 MB，完成分析后可自行删除整次报告目录。
每个 case 都在计时后校验日志条数、消息顺序和解密。

## 对比内容

- `demo_format`：与原生 Demo 一样的 `String(format:)` 消息、实际 `DemoSession.swift`、level 查询和 `session.write()`。
  同时提供无采样的 baseline 与链接独立采样 Core 的 sampled 进程，交替顺序运行。
- `demo_prebuilt`：提前构造相同消息，保留 Swift / Objective-C / Core 调用；观察格式化与分配是否显著影响总耗时。
- `core_prebuilt`：相同 UTF-8 消息提前构造，直接循环调用 C++ Core；观察语言封装之外的写入成本。
- `format_only`：仅构造同样的消息并计算字符数校验和，观察 Foundation 格式化成本。

除 format_only 外，每种方式均测明文与 AES。每个 worker 先在独立文件中预热，再用全新文件计时。
初始化、预构造、显式 flush、读取校验和报告输出不在写入计时内。
控制组改变对象分配和生命周期，只用于定位方向，不能机械地用两个总耗时相减归因。

分段覆盖消息格式化、Swift 及桥接残余、Objective-C UTF-8 转换及检查、线程锁、元数据、
FlatBuffers、AES、跨进程 flock 加锁/解锁、fstat、stat、映射刷新、扩容、mmap/munmap 和追加提交。
高频阶段默认每 64 条采样一次；打开关闭文件、扩容、映射及解除映射完整计时。
阶段为嵌套互斥耗时估计，子阶段从父阶段扣除；占比不强行归一为 100%，报告保留原始调用数及采样/完整计时。
`swift_other` 还包含计时器与采样记账成本。以 baseline 判断真实性能，sampled 只用于归因；
报告显示采样开销比，超过 5% 时应增大 stride 复核。
报告记录 CPU、系统、运行架构、Rosetta 状态、源码哈希和编译选项，方便对比两台电脑。

命令行可调整轮数或降低采样频率：

```bash
/Applications/MXLoggerProfile.app/Contents/MacOS/MXLoggerProfile --run --rounds 3 --stride 256 --report-dir "$HOME/Desktop/mxlogger-profile"
```

本地构建：`bash scripts/build_macos_profile.sh`。使用 Release 优化（Swift -O、C/C++ -Os），
重用实际 DemoSession 和 Objective-C wrapper 源码；独立 CLI 构建不通过 CocoaPods，不包含普通 Demo 的 UI。
构建脚本先用 256 条运行快速自测；独立 CI 再用 10 万条执行全部场景一轮。
CI 机器的耗时不能当作待测 Mac 的性能结果，请在发生 1.5 秒耗时的那台电脑上运行应用。
普通构建不定义 `MXLOGGER_MACOS_PROFILING`，所有 Core 采样宏展开为空，普通 Demo 不包含统计器。
分支删除后诊断代码即可一并移除。
