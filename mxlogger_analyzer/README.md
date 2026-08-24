# mxlogger_analyzer

MXLogger 日志解析器（Flutter，自带基于 stream 的轻量状态管理，UI 对齐 Claude Design 设计稿 `MXLogger.dc.html`）。

导入 [MXLogger](https://github.com/coder-dongjiayi/MXLogger) 产出的 `.mx` mmap 二进制日志
（AES-CFB-128 解密 + flatbuffer 反序列化），也支持 JSON-lines 文本日志（`.log/.txt/.json`），
sqlite 入库后提供检索、过滤与 JSON 语法树查看。

仿照 1.x 拆为两层（本目录是桌面壳，内核可单独发布嵌入 app）：

```
mxlogger_analyzer/            # 桌面壳（macOS/Windows/Linux 入口，薄 main.dart）
└── mxlogger_analyzer_lib/    # 分析器内核包：全部 UI/解析/数据库 + MXAnalyzer 嵌入 API
```

**嵌入宿主 app**（iOS/Android，悬浮球 + 底部弹窗，用法见 `mxlogger_analyzer_lib/README.md`）。
打开弹窗不自动解析：先是空白页 + 「刷新日志」按钮，由用户主动触发；每次刷新清空数据库重新解析。

```dart
MXAnalyzer.showDebug(navigatorKey.currentState!.overlay!,
    diskcachePath: logger.diskcachePath!, cryptKey: key, iv: iv);

// 日志换过密钥（同一文件里的记录 Key/IV 不同）时传多组，逐条按顺序尝试
MXAnalyzer.showDebug(navigatorKey.currentState!.overlay!,
    diskcachePath: logger.diskcachePath!,
    cryptPairs: const [
      MxCryptPair(key: "current-key", iv: "current-iv"),
      MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
    ]);
MXAnalyzer.dismiss();
```

## 页面

**首次使用三步向导**（步骤间滑动转场）：
① 拖入/选择日志文件（`.mx/.log/.txt/.json`，未选时「下一步」不可用）→
② 配置解密 KEY/IV（持久化，未加密留空）：可添加多组并逐组勾选，
勾选框里的序号即解密尝试顺序——第一组解不开自动换下一组 → 点「开始导入」→
③ 真实进度 loading（解析按字节偏移、写库按条数）→ 完成自动进入日志详情页。
读取失败回退到第①步，解析失败（多为 Key/IV 错误）回退到第②步。

**数据页空态**：再次打开且无数据时，拖入或点击选择日志文件即可导入，可返回修改 Key/IV。

**数据页**：
- Header：总条数 / 起止时间 / 文件名，分享（导出 txt）、改 Key/IV 重解析、更换文件、
  清除数据（二次确认，清空后回到首次引导页）、深浅主题切换
- 等级分布条（按占比分段、可点击过滤）+ DEBUG–FATAL 等级 chips（带紧凑计数 1.2k/5.8w）
- Header 信息卡片：折叠摘要，展开后标量紧凑网格 + 嵌套对象 JSON 树（key 按日志原样显示）、一键复制
- 搜索（180ms 防抖 + 全部/内容/Tag/Name 范围 + × 一键清除）、时间范围过滤、折叠/展开全部
- 生效筛选 chips（#tag / @name / 时间，可单个移除或全部清除）
- 日志卡片：等级色条与徽标（FATAL 品红描边光）、@name/#tag 点击过滤、搜索命中高亮、
  折叠单行预览、JSON 正文语法着色树（默认展开 2 层）、单条分享/全屏/复制
- 全屏详情弹窗（Esc 关闭）、回顶/回底、胶囊 toast

**移动端适配**（按可用宽度分 720 / 480 两级断点，规则集中在 `global/util/mx_responsive.dart`）：
留白收窄、文案让位于图标、等级 chips 横向滚动、输入竖排铺满、按钮加大到可点尺寸、
弹窗铺满整屏、安全区避让。详见 `mxlogger_analyzer_lib/README.md`。

## 架构

```
mxlogger_analyzer_lib/lib/
├── mxlogger_analyzer_lib.dart  # 伞文件：导出 MXAnalyzer 嵌入 API / app 壳 / 核心 provider
└── src/
    ├── app/            # App 入口、MXTokens 双主题 tokens、l10n（zh/en）
    ├── data/           # .mx 二进制解析 / JSON-lines 解析 / sqlite 封装 / 示例数据
    ├── dependencies/   # vendored 纯 Dart 依赖：aes_crypt、flat_buffers（排除 lint）
    ├── embed/          # MXAnalyzer：悬浮球 + 底部弹窗（嵌套 MaterialApp，自带主题/l10n/导航）
    ├── global/         # state（stream 状态管理内核）、store（主题/Key-IV/数据库状态）、host（宿主能力：MXPrefs 存储 / 选文件 / 拖入，桌面壳注入插件实现）、util、widget
    └── screens/        # main（壳+导入结果消费）/ landing（投放页）/ home（数据页）
        └── home/       # screen + store/ + repository + model/ + widget/
```

分层严格单向：`Screen → Store(MXState/MXAsyncState) → Repository → data 层`，UI 不直连数据库。
状态管理是自研的 stream 方案（`global/state`）：`MXState<T>` 持有值并广播变化，
`MXAsyncState<T>` 负责异步取数（懒加载 + refresh 保留旧值），组件侧用 `MXConsumerWidget` +
`ref.watch/select/listen` 订阅，`MXStore` 汇总全部状态并由 `MXScope` 注入组件树。
导入流程解析成功后才原子替换数据库（改 Key/IV 重解析失败保留旧数据）。
解密与反序列化在 isolate 内执行；以微秒时间戳为唯一标识去重。

## 开发

```bash
flutter pub get
flutter run -t lib/main_desktop.dart -d macos   # 或 windows / linux

# 真机验证嵌入效果（悬浮球 + 弹窗）：由 flutter_mxlogger 真实写入加密 .mx，再用分析器读取
flutter run -t lib/main_package.dart -d <iOS/Android 设备>

cd mxlogger_analyzer_lib
flutter test                # 解析往返 / 数据库查询 / 导入链路 / 页面 widget 测试
flutter analyze
```

生成示例 `.mx` 文件（明文 + 加密，key 为 `mxlogger123`）用于验证导入：

```bash
dart run tool/generate_sample_mx.dart sample
```

改动品牌 logo 后重新生成 macOS AppIcon（复用 `MXLogoPainter` 矢量直绘各尺寸）：

```bash
flutter test tool/generate_app_icon.dart
```

打包桌面可执行文件（产物落到 `dist/`，命名带版本号与架构）：

```bash
dart run tool/build_desktop.dart          # 出当前系统的包（macOS zip / Windows zip / Linux tar.gz）
dart run tool/build_desktop.dart --dmg    # macOS 额外出可拖拽安装的 .dmg
dart run tool/build_desktop.dart --no-build   # 复用已有构建产物，只重新打包
```

Flutter 桌面不支持交叉编译（macOS 要 Xcode 工具链、Windows 要 MSVC、Linux 要 GTK），
三端产物 = 在三台机器（或 CI 的 macos / windows / ubuntu 三个 runner）上各跑一次同一条命令。

## 日志格式

**.mx 二进制**（小端）：`[uint32 totalSize][uint32 itemSize][flatbuffer item]...`，
item 可选 AES-CFB-128 加密（key/iv 补零到 16 字节，iv 缺省回退 key）。
flatbuffer 字段：`name / tag / msg / level(int8: 0-4) / threadId(int32) / isMainThread(uint8) / timestamp(uint64 微秒)`；
首条 `name == "com.djy.mxlogger.fileHeader"` 为文件头（写入端环境信息）。
`tag` 多值用逗号/空格分隔（如 `net,login`），展示与点击过滤均按分词处理。

**JSON-lines 文本**：首行可为 header map，其后每行
`{"ts": 毫秒或ISO时间, "level": "debug|info|warning|error|fatal", "name": "...", "tags": [...], "content": "..."}`。
