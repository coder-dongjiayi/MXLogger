# mxlogger_analyzer_lib

MXLogger 2.0 日志分析器内核：导入、解密（AES-128-CFB）、解析并检索 `.mx` 二进制日志文件。

两种使用方式：

1. **独立 app**：仓库根目录的 `mxlogger_analyzer` 桌面壳直接依赖本包（macOS/Windows/Linux）。
2. **嵌入宿主 app**：通过 `MXAnalyzer` 在 iOS/Android app 内以「悬浮球 + 底部弹窗」形式查看本机日志。

## 嵌入用法

```dart
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// MaterialApp(navigatorKey: navigatorKey, ...)

// 显示悬浮入口（品牌 logo 方块：拖动移位，单击打开分析器，双击关闭）
MXAnalyzer.showDebug(
  navigatorKey.currentState!.overlay!,
  diskcachePath: logger.diskcachePath!, // MXLogger 日志目录
  cryptKey: "your-16-byte-key",
  iv: "your-16-byte-iv",
);

// 移除悬浮球并释放数据库
MXAnalyzer.dismiss();
```

说明：

- 弹窗内是自带 Navigator / 主题 / 中英文多语言的嵌套 MaterialApp，
  **不要求**宿主配置状态容器或 `AppLocalizations`，仅要求存在 `MaterialApp`（提供 Overlay）。
- `cryptKey` / `iv` 作为**一组**解密参数写入设置并勾选（已有同样的一组则只确保勾选）；
  多组用 `cryptPairs: [MxCryptPair(key: ..., iv: ...), ...]` 传入，按给定顺序置于表首。
  用户也可在分析器里自己加组并勾选。解密时**逐条**按勾选框里的序号尝试，解不开换下一组
  ——同一个文件里的记录由不同 Key/IV 加密（写入端换过密钥）也能全部解出来。
- **打开弹窗不解析**：解析只由用户点「刷新」触发（日志量大时解析耗时，
  不该卡在打开弹窗上）。库里有上次解析的结果就直接展示，没有才是空白页 + 「刷新日志」按钮。
  刷新入口在 header 右上角（替代桌面端的「更换文件」）。
- **解析结果持久化在 sqlite**，重启 app 打开弹窗仍是上次的结果（不重新解析）；
  要拿最新日志点刷新。
- **每次刷新都清空数据库重新解析** `diskcachePath` 下的 `.mx/.log/.txt/.json`，
  不与上次结果合并，所见即本次扫描的全量结果。
- 数据库默认存放在 `getApplicationSupportDirectory()`，
  可用 `MXAnalyzer.initialize(databasePath: ...)` 或 `showDebug(databasePath: ...)` 覆盖。
- **依赖克制**：嵌入模式不依赖 shared_preferences / file_picker / desktop_drop
  之类的 KV 存储与文件插件——Key/IV 每次由 `showDebug` 传入，设置默认只存内存
  （悬浮球关了再开仍在，杀进程后回默认值）。需要把主题/语言/用户自己加的
  解密参数组持久化时，实现 `MXPrefs` 并经 `MXAnalyzer.initialize(prefs: ...)` 注入。
  选文件 / 拖入 / 设置落盘属于宿主能力（`MXHost`），由桌面壳注入插件实现。

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
排查问题时只有时分秒不够用；宽度由「⋮」收敛操作按钮腾出）。

筛选区（等级分布条+等级 chips、搜索框、时间范围/折叠按钮、时间面板）在手机上占近半屏，
故左下角常驻一个悬浮按钮**手动收起/展开**（品牌行与右上角操作始终保留）。
收起用 `MXCollapsible`（heightFactor 动画到 0 + 裁剪）而非条件构建：
子树保持挂载，搜索框内容与焦点不会因收起而丢失。
不做随滚动自动收起——手指一动界面就跳，反而不好用。

安全区：嵌入弹窗顶部在屏幕 15% 处，故 `MXAnalyzer` 会移除顶部 padding；
底部 home indicator 由列表底部留白、悬浮按钮、弹窗底栏与 toast 各自避让。
回归护栏见 `test/mobile_layout_test.dart`（iPhone 尺寸下渲染，溢出即测试失败）。

## 独立 app 入口

内核不直接依赖 shared_preferences / file_picker / desktop_drop，
壳工程用这些插件实现 `MXHost`（设置落盘 / 选文件 / 拖入文件）后注入
（参考桌面壳 `lib/src/host/desktop_host.dart`）：

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final MXHost host = await createDesktopHost(); // 壳工程自己的 MXHost 实现
  runApp(MXScope(
    store: MXStore(host: host),
    child: const MXLoggerAnalyzerApp(),
  ));
}
```

## 开发

- 多语言：文案在 `lib/src/app/l10n/app_zh.arb` / `app_en.arb`，
  修改后在包目录执行 `flutter gen-l10n`（产物提交在 `lib/src/app/l10n/gen/`）。
- 测试：`flutter test`（解析器 / 数据库 / 分页 / 各弹窗与页面 widget 测试）。
