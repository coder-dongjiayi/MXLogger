[English](README.md) | 简体中文

# mxlogger_analyzer_lib

MXLogger 2.0 日志分析器内核：导入、解密（AES-CFB-128）、解析并检索 [MXLogger](https://github.com/coder-dongjiayi/MXLogger)
产出的 `.mx` mmap 二进制日志，也支持 JSON-lines 文本日志（`.log/.txt/.json`）。
解析结果入 sqlite，提供搜索、等级/时间/Tag/Name 过滤与 JSON 语法树查看。

两种使用方式，入口代码分别是仓库里的两个 `main`：

| 方式 | 入口 | 说明 |
| --- | --- | --- |
| 独立 app | [`lib/main_desktop.dart`](../lib/main_desktop.dart) | macOS/Windows/Linux 桌面壳，拖入或选择日志文件后分析 |
| 嵌入宿主 app | [`lib/main_package.dart`](../lib/main_package.dart) | iOS/Android app 内以「悬浮球 + 底部弹窗」查看本机日志 |

## 界面

**桌面数据页**：等级分布条 + 等级 chips、搜索与时间过滤、日志卡片里的 JSON 语法着色树、
`@name` / `#tag` 点击即过滤、单条日志的信息 / 分享 / 全屏 / 复制。
右上角可一键切浅色主题（深浅两套 tokens 全量对齐）。

![桌面数据页](screenshots/desktop_dark.png)

**首次使用三步向导**：① 拖入/选择日志文件 → ② 配置解密 KEY/IV（可多组）→ ③ 真实进度解析导入。

![首次引导向导](screenshots/desktop_wizard.png)

**单条日志全屏详情**（Esc 关闭）：Name / Tags / 时间 / 类型 + 完整 JSON 树，可分享或整条复制。

![日志全屏详情](screenshots/desktop_detail.png)

**嵌入宿主 app**（手机）：占屏幕 85% 的底部弹窗，留白收窄、文案让位于图标、
等级 chips 横向滚动、日志卡片默认折叠、操作收进「⋯」。

![嵌入宿主 app 的底部弹窗](screenshots/mobile_embed.png)

## 独立 app：桌面壳入口

内核不直接依赖 shared_preferences / file_picker / desktop_drop / share_plus，
壳工程用这些插件实现 `MXHost`（设置落盘 / 选文件 / 拖入文件 / 系统分享）后注入，
入口因此很薄 —— [`lib/main_desktop.dart`](../lib/main_desktop.dart) 全文：

```dart
import 'package:flutter/material.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

import 'package:mxlogger_analyzer/src/host/desktop_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 桌面壳注入平台能力（shared_preferences / file_picker / desktop_drop），
  // 内核自身不依赖这些插件
  final MXHost host = await createDesktopHost();
  runApp(MXScope(
    store: MXStore(host: host),
    child: const MXLoggerAnalyzerApp(),
  ));
}
```

`createDesktopHost()`（见 [`lib/src/host/desktop_host.dart`](../lib/src/host/desktop_host.dart)）返回的
`MXHost` 有四项能力，缺哪项就少哪个入口，不会报错：

| 能力 | 桌面壳实现 | 不提供时 |
| --- | --- | --- |
| `prefs` | shared_preferences | 退化为 `MXMemoryPrefs`，设置只存内存 |
| `pickLogFiles` | file_picker | 不展示「选择文件」入口 |
| `dropTargetBuilder` | desktop_drop | 页面原样渲染，不套拖放目标 |
| `share` | share_plus | 「分享」降级为复制到剪贴板 |

运行：

```bash
flutter run -t lib/main_desktop.dart -d macos   # 或 windows / linux
```

## 嵌入宿主 app：真机入口

[`lib/main_package.dart`](../lib/main_package.dart) 是完整闭环的真机调试入口：
由 flutter_mxlogger 在本机真实写入加密 `.mx`，再用悬浮球打开分析器读取同一目录。

```bash
flutter run -t lib/main_package.dart -d <iOS/Android 设备>
```

### 1. 宿主先写日志

`fileHeader` 里塞设备环境（device_info_plus），分析器的 Header 弹窗会把它展开成标量网格 + JSON 树：

```dart
final MXLogger logger = await MXLogger.initialize(
  nameSpace: "flutter.mxlogger",
  storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
  fileHeader: jsonEncode(header),      // 写入端环境信息
  consoleEnable: true,
  cryptKey: "bnijioijuojiuoju",        // 16 字节
  iv: "njkoiuhjbjuiasdh",
);

logger.debug("这是条debug状态下的调试信息", name: "login", tag: "login,service");
logger.info(jsonEncode(response), name: "network", tag: "network,POST,200");
logger.error(flutterErrorStack, name: "flutter", tag: "flutter,crash");
logger.fatal("数据库连接丢失，业务不可用", name: "database", tag: "db,fatal");
```

### 2. 悬浮球打开分析器

`MXAnalyzer` 挂在宿主 app 的 `Overlay` 上（拖动移位，单击打开弹窗，双击关闭），
路由切到二级页面也常驻：

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

await MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath,   // MXLogger 的日志目录
  // 解密参数由宿主全量传入（未加密传空数组）；多组时按顺序依次尝试
  cryptPairs: [
    MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
    // MxCryptPair(key: "legacy-key", iv: "legacy-iv"),
  ],
  onShare: _shareWithSharePlus,
);

MXAnalyzer.dismiss();   // 移除悬浮球并释放数据库连接
```

### 3. 分享由宿主接（可选降级）

内核不依赖分享插件：宿主自己接 share_plus 后经 `onShare` 注入，
返回 `false`（当前环境不可用）时内核降级复制到剪贴板。
`MXShareRequest.fileName` 非空表示希望以文本文件形式分享（导出日志），
`origin` 是触发控件的屏幕矩形（iPad/macOS 的 popover 面板需要）：

```dart
Future<bool> _shareWithSharePlus(MXShareRequest request) async {
  final ShareResult result;
  if (request.fileName != null) {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(request.text)),
          name: request.fileName,
          mimeType: "text/plain",
        ),
      ],
      fileNameOverrides: [request.fileName!],
      sharePositionOrigin: request.origin,
    ));
  } else {
    result = await SharePlus.instance.share(ShareParams(
      title: request.title,
      text: request.text,
      sharePositionOrigin: request.origin,
    ));
  }
  return result.status != ShareResultStatus.unavailable;
}
```

### 4. 可选预配置

```dart
MXAnalyzer.initialize(
  databasePath: dir.path,   // sqlite 存放目录，默认 getApplicationSupportDirectory()
  prefs: myPrefs,           // 实现 MXPrefs 即可持久化主题/语言/用户自己加的解密参数组
);
```

## 嵌入模式的行为约定

- 弹窗内是自带 Navigator / 主题 / 中英文多语言的嵌套 MaterialApp，
  **不要求**宿主配置状态容器或 `AppLocalizations`，仅要求存在 `MaterialApp`（提供 Overlay）。
- `cryptPairs` 传入的组置于设置表首并勾选（已有同样的一组则只确保勾选），
  用户在分析器里自己加的组原样保留。解密时**逐条**按勾选框里的序号尝试，解不开换下一组
  ——同一个文件里的记录由不同 Key/IV 加密（写入端换过密钥）也能全部解出来。
- **打开弹窗不解析**：解析只由用户点「刷新」触发（日志量大时解析耗时，
  不该卡在打开弹窗上）。库里有上次解析的结果就直接展示，没有才是空白页 + 「刷新日志」按钮。
  刷新入口在 header 右上角（替代桌面端的「更换文件」）。
- **解析结果持久化在 sqlite**，重启 app 打开弹窗仍是上次的结果（不重新解析）；
  要拿最新日志点刷新。
- **每次刷新都清空数据库重新解析** `diskcachePath` 下的 `.mx/.log/.txt/.json`，
  不与上次结果合并，所见即本次扫描的全量结果。
- **依赖克制**：嵌入模式不依赖 shared_preferences / file_picker / desktop_drop
  之类的 KV 存储与文件插件——Key/IV 每次由 `showDebug` 传入，设置默认只存内存
  （悬浮球关了再开仍在，杀进程后回默认值）。选文件 / 拖入 / 设置落盘属于宿主能力
  （`MXHost`），由桌面壳注入插件实现。

## 移动端适配

同一套 UI 兼顾桌面与手机，按可用宽度（非 Platform）分两级断点，
规则集中在 `lib/src/global/util/mx_responsive.dart`（`context.isMobileLayout` / `isNarrowLayout`）：

- **≤720**：左右留白 20→14；品牌副标题与工具栏按钮文案隐藏（只留图标）；
  等级 chips 单行横向滚动铺到屏幕边缘；搜索框独占一行；
  Key/IV 与时间范围输入竖排铺满；操作按钮加大（30→38 / 28→36 / 悬浮 36→44）；
  日志区留白压到最小（列表左右 2、卡片内左 6、折叠钮 16、元素间距 5，
  屏幕窄，边距吃的都是正文宽度）；
  日志卡片默认折叠（只留单行预览），4 个操作收进「⋯」，点开从底部弹面板；
  日志详情与 Header 弹窗铺满整屏（无圆角、底栏按钮等宽平分）；
  输入字号统一 16。
- **≤480**：Header 标量网格单列。

日志时间戳恒显示完整 `年-月-日 时:分:秒.毫秒`（设计稿窄屏隐藏日期的规则未采用，
排查问题时只有时分秒不够用；宽度由「⋯」收敛操作按钮腾出）。

筛选区（等级分布条+等级 chips、搜索框、时间范围/折叠按钮、时间面板）在手机上占近半屏，
故左下角常驻一个悬浮按钮**手动收起/展开**（品牌行与右上角操作始终保留）。
收起用 `MXCollapsible`（heightFactor 动画到 0 + 裁剪）而非条件构建：
子树保持挂载，搜索框内容与焦点不会因收起而丢失。
不做随滚动自动收起——手指一动界面就跳，反而不好用。

安全区：嵌入弹窗顶部在屏幕 15% 处，故 `MXAnalyzer` 会移除顶部 padding；
底部 home indicator 由列表底部留白、悬浮按钮、弹窗底栏与 toast 各自避让。
回归护栏见 `test/mobile_layout_test.dart`（iPhone 尺寸下渲染，溢出即测试失败）。

## 开发

- 多语言：文案在 `lib/src/app/l10n/app_zh.arb` / `app_en.arb`，
  修改后在包目录执行 `flutter gen-l10n`（产物提交在 `lib/src/app/l10n/gen/`）。
- 测试：`flutter test`（解析器 / 数据库 / 分页 / 各弹窗与页面 widget 测试）。
- 本文档的截图由代码固定尺寸与假数据生成，换版本重跑一次即可整套更新
  （跑在真实 macOS 应用里，headless 的 `flutter test` 只有占位字体）：

  ```bash
  cd ..   # 桌面壳工程
  flutter test integration_test/generate_screenshots_test.dart -d macos \
      --dart-define=OUT_DIR=$PWD/mxlogger_analyzer_lib/screenshots
  ```

  沙盒应用写不进仓库目录时会退回应用支持目录并打印路径，按提示把 PNG 拷回
  `mxlogger_analyzer_lib/screenshots/` 即可。
