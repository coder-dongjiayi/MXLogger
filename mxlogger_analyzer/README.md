# mxlogger_analyzer

MXLogger 日志解析器（Flutter，自带基于 stream 的轻量状态管理，UI 对齐 Claude Design 设计稿 `MXLogger.dc.html`）。

导入 [MXLogger](https://github.com/coder-dongjiayi/MXLogger) 产出的 `.mx` mmap 二进制日志
（AES-CFB-128 解密 + flatbuffer 反序列化），sqlite 入库后提供检索、过滤与 JSON 语法树查看。
只支持 `.mx`，不解析其他格式的日志文件。

仿照 1.x 拆为两层（本目录是桌面/Web 壳，内核可单独发布嵌入 app）：

```
mxlogger_analyzer/            # 桌面/Web 壳（main_desktop.dart / main_web.dart）
└── mxlogger_analyzer_lib/    # 分析器内核包：全部 UI/解析/数据库 + MXAnalyzer 嵌入 API
```

**嵌入宿主 app**（iOS/Android，悬浮球 + 底部弹窗，用法见 `mxlogger_analyzer_lib/README.md`）。
打开弹窗不自动解析：先是空白页 + 「刷新日志」按钮，由用户主动触发；每次刷新清空数据库、重新解析目录下的 `.mx`。

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

## 普通 Web 版

`lib/main_web.dart` 是普通浏览器入口，复用 Chrome 扩展的浏览器宿主与完整分析器页面，
不需要安装扩展。支持选择/拖入 `.mx`、本地解密、搜索筛选、分页、详情/上下文、TXT 下载、
主题/语言和字体设置；解析与 SQLite 查询在独立 Worker 中执行，日志缓存保存在 IndexedDB。
日志不会上传到服务器，KEY/IV 默认只保存在当前会话，可按需勾选本地保存。

在本目录运行：

```bash
flutter pub get
bash ../scripts/prepare_web.sh             # 编译 Worker，准备共享浏览器资源
flutter run -d chrome -t lib/main_web.dart # 开发调试

bash ../scripts/build_web.sh              # 发布构建，产物在 build/web/
# 部署到子路径时：
bash ../scripts/build_web.sh --base-href /mxlogger/
```

构建和资源准备脚本统一放在仓库根目录的 `scripts/`，也可在仓库根目录执行
`bash scripts/build_web.sh`。脚本根据自身位置定位工程，不依赖当前工作目录。
`prepare_web.sh` 使用已缓存的依赖；首次运行先执行 `flutter pub get`。
修改 Worker 或扩展的浏览器资源后重新运行准备脚本。资源准备完成后，也可直接运行
`flutter build web --release -t lib/main_web.dart --no-web-resources-cdn`。
部署时将整个 `build/web/` 目录交给静态服务器，以 HTTPS 或 localhost 访问；
不要直接双击 `index.html`。数据库和设置按站点来源隔离，普通 Web 版与扩展不共享缓存。
同一站点同时只允许一个分析器标签页持有日志数据库。

## 页面

**首次使用三步向导**（步骤间滑动转场）：
① 拖入/选择 `.mx` 日志文件（未选时「下一步」不可用）→
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
  折叠单行预览、JSON 正文语法着色树（默认展开 2 层）、单条上下文/分享/全屏/复制
- 上下文面板：以某条日志为锚点展示它在全部日志（忽略当前筛选）里前后各 20 条，
  两端可继续加载，锚点强调色高亮，排列跟随列表正/倒序——筛出一堆 ERROR 后无需清掉筛选即可看前后发生了什么
- 全屏详情弹窗（Esc 关闭）：正文内搜索——高亮全部命中、「第 N / 共 M 处」、回车 / Shift+回车 跳转并自动滚到命中处，
  JSON 折叠节点内的命中自动展开；回顶/回底、胶囊 toast

**移动端适配**（按可用宽度分 720 / 480 两级断点，规则集中在 `global/util/mx_responsive.dart`）：
留白收窄、文案让位于图标、等级 chips 横向滚动、输入竖排铺满、按钮加大到可点尺寸、
弹窗铺满整屏、安全区避让。详见 `mxlogger_analyzer_lib/README.md`。

## 架构

```
mxlogger_analyzer_lib/lib/
├── mxlogger_analyzer_lib.dart  # 伞文件：导出 MXAnalyzer 嵌入 API / app 壳 / 核心 provider
└── src/
    ├── app/            # App 入口、MXTokens 双主题 tokens、l10n（zh/en）
    ├── data/           # .mx 二进制解析（解密 + flatbuffer） / sqlite 封装
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

重新生成 `mxlogger_analyzer_lib/README.md` 里的界面截图（尺寸与假数据都由代码固定，
跑在真实 macOS 应用里才拿得到系统字体；沙盒写不进仓库目录时会退回应用支持目录并打印路径）：

```bash
flutter test integration_test/generate_screenshots_test.dart -d macos \
    --dart-define=OUT_DIR=$PWD/mxlogger_analyzer_lib/screenshots
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

## Chrome 扩展（第二阶段：完整页面）

独立工程在 `chrome_extension/`，复用内核完整页面、解析器和 SQLite 查询。
浏览器 Worker 执行解密与查询，SQLite WASM 通过 IndexedDB 保存数据；
Flutter、CanvasKit、SQLite 和中文字体均打包到扩展中，支持离线使用。

```bash
bash ../scripts/build_analyzer_chrome_extension.sh 1.0.0
node chrome_extension/tool/verify.cjs
```

以上命令在本目录运行；在仓库根目录构建可用
`bash scripts/build_analyzer_chrome_extension.sh 1.0.0`。
**每次打包必须显式传入版本号**，缺少参数或版本格式不合法时会在构建前退出。
版本号遵循 [Chrome 规则](https://developer.chrome.com/docs/extensions/reference/manifest/version)：
由 1–4 段 `0–65535` 的整数以点分隔，不能有前导零，也不能全部为零；例如 `1.0.0` 或 `1.0.0.1`。
传入值会写入解压目录和 ZIP 内的 `manifest.json`，不依赖源码中的默认版本；
构建结束会输出实际版本号，`dist/package-size.json` 也会记录该版本。
构建需要 Flutter / Dart、Python 3，以及已缓存的 pub 依赖。
首次在新机器上先进入 `chrome_extension/` 运行 `flutter pub get`，构建脚本之后使用离线依赖。
验证脚本默认使用 macOS 的 Google Chrome，可通过 `CHROME_BIN` 指定其他路径；
它使用临时用户目录和 DevTools pipe，不接触日常浏览器配置。

产物为 `chrome_extension/dist/mxlogger-chrome-prototype.zip` 和同名未压缩目录。
打开 `chrome://extensions`，开启开发者模式，选择「加载已解压的扩展程序」并选中该目录，
然后点击扩展图标打开分析器。首次使用依次选择日志、配置解密参数、开始导入。
示例文件位于 `chrome_extension/web/samples/`，加密示例 KEY 是 `mxlogger123`，IV 留空。
升级时保持原有加载目录，点击扩展卡片的重新加载按钮，再刷新分析器标签页。

支持多文件选择/拖入、替换或合并去重、多组 KEY / IV、重新解析、日志卡片与 JSON 树、
详情搜索、全局上下文、关键词/等级/Tag/Name/时间筛选、排序、滚动分页、复制与 TXT 下载。
桌面/Web 数据页在语言按钮后提供「收起筛选区」，收起等级分布与搜索工具栏，
展开后保留当前搜索/筛选；手机嵌入模式沿用原来的左下角按钮。
一次只允许一个分析器页面持有数据库。导入、解密、查询和入库均在 Worker 中执行，
日志列表只接收当前页和统计信息。多文件导入在一个事务中提交，写入失败保留原有数据。
相同内容重导逐字段核验后复用缓存；清除操作关闭并重建缓存文件，避免逐条删除大数据库。
清空期间弹框显示 loading 并禁止重复点击，失败可重试；导入文件大小自动显示为 KB / MB / GB。
日志缓存、主题和语言选择保存在扩展自己的本地存储中；KEY / IV 默认只存当前标签页会话。
Web 解密配置可勾选「在此浏览器保存 KEY 和 IV」，下次打开自动恢复；取消勾选即删除
本地保存的密钥，当前会话仍可使用。解密始终在本地完成，密钥不会上传到任何服务器。
首次语言跟随 Chrome：中文使用中文，其余语言回退英文；手动选择后优先使用保存的语言。
刷新后仍可查询缓存日志；如需重新解析，必须重新选择源文件，未保存的解密参数需要重新填写。
工具栏图标单独按 16/32/48/128 像素矢量生成，减少外边距并提高小尺寸对比度：
在工程根目录运行 `flutter test --no-pub tool/generate_chrome_icons.dart` 可重新生成。
验证报告与深浅主题、详情、上下文预览输出到 `chrome_extension/dist/`。
浏览器功能测试的 JSON/中文/日文/多文件夹具位于 `chrome_extension/tool/fixtures/`，
不打入扩展；重新生成可运行 `flutter test --no-pub tool/generate_browser_fixture.dart`。
可选大文件回归：在扩展目录运行 `node tool/verify.cjs --large /路径/明文.mx /路径/加密.mx`
（使用性能测试文件的 KEY `mxlogger_key_123`、IV `mxlogger_iv_4567`）。

扩展打包只保留实际配置的 Chromium CanvasKit 渲染器，剔除其他渲染器、
调试符号和旧字体文件。主包只内置英文、中文界面/日期选择器用字和常用符号字体，
Roboto 保留全部字符并压缩为单份 WOFF2；符号字库保留全部 BMP 字符及界面用字，
罕见的补充平面符号可导入 `dist/font-packs/NotoSansSymbols2.woff2` 或 `NotoSansMath.woff2`。
完整中文及常用日文日志字库拆为可选字体包。浏览器语言与实际日志缺字会触发推荐；
底部「字体设置」可点击下载安装，或导入本地 WOFF2 / TTF / OTF 文件（最大 32 MB）。
只有主动点击安装才请求固定版本的 Google Fonts 字体，优先使用 jsDelivr 镜像，
连接失败、传输停滞或文件校验失败时自动切换 GitHub 官方源。连接等待上限为 12 秒，
无数据传输等待上限为 20 秒，每个来源的下载上限为 120 秒。显示具体失败原因，
用户取消时停止请求且不切换来源。两源均通过同一 SHA-256 校验后保存到扩展的
IndexedDB；日志和 KEY / IV 不参与下载请求。离线打开会自动恢复已缓存字体。
下载失败可改用本地字体；缓存移除后当前页面仍可使用，下次打开不再加载。
`chrome_extension/dist/font-packs/mxlogger-cjk.woff2` 是独立的 7.42 MiB 压缩字体，
不会进入扩展 ZIP，可直接在「字体设置」导入；在线安装使用官方原始 TTF（约 16.95 MiB）。
体积明细输出到 `chrome_extension/dist/package-size.json`。
仓库提供生成后的字体，正常构建不需要字体工具。修改界面文案后安装 `fonttools[woff]`，
运行 `python3 tool/prepare_fonts.py` 更新界面字库、缺字检测清单和可选字体包；
完整字库的无损压缩仍由 `python3 tool/compress_font.py` 生成。

## 日志格式

**.mx 二进制**（小端）：`[uint32 totalSize][uint32 itemSize][flatbuffer item]...`，
item 可选 AES-CFB-128 加密（key/iv 补零到 16 字节，iv 缺省回退 key）。
flatbuffer 字段：`name / tag / msg / level(int8: 0-4) / threadId(int32) / isMainThread(uint8) / timestamp(uint64 微秒)`；
首条 `name == "com.djy.mxlogger.fileHeader"` 为文件头（写入端环境信息）。
`tag` 多值用逗号/空格分隔（如 `net,login`），展示与点击过滤均按分词处理。

