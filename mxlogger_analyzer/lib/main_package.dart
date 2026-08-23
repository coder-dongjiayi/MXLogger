/// 真机（iOS/Android）调试入口：验证 [MXAnalyzer] 嵌入宿主 app 的效果。
///
/// 与桌面壳入口 `main_desktop.dart` 不同，这里由 flutter_mxlogger 在本机真实写入
/// 加密 `.mx` 日志，再用悬浮球打开分析器读取同一目录，形成完整闭环。
///
/// 运行：`flutter run -t lib/main_package.dart -d <手机设备>`
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mxlogger/flutter_mxlogger.dart';
import 'package:mxlogger_analyzer_lib/mxlogger_analyzer_lib.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

/// 用 share_plus 弹系统分享面板：携带 fileName 时以文本文件分享，
/// 否则分享纯文本。返回 false（当前环境不可用）时内核降级复制剪贴板。
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

/// 宿主 app 的 navigatorKey：MXAnalyzer 需要它的 overlay 挂载悬浮球
final GlobalKey<NavigatorState> _navigatorStateKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  /// 16 字节 AES key / iv，需与分析器设置里的解密参数一致（showDebug 会自动写入）
  static const String _cryptKey = "bnijioijuojiuoju";
  static const String _iv = "njkoiuhjbjuiasdh";

  MXLogger? _mxLogger;
  String _status = "初始化中…";
///abchjilokiuihjng
  ///abchjilokiuihqqq
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 文件头信息：写入设备环境，验证分析器 Header 信息卡片的标量网格 + JSON 树
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    final Map<String, dynamic> header;
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      header = androidInfo.data;
    } else if (Platform.isIOS) {
      final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      header = iosInfo.data;
    } else {
      header = <String, dynamic>{
        "platform": Platform.operatingSystem,
        "version": Platform.operatingSystemVersion,
      };
    }

    final MXLogger logger = await MXLogger.initialize(
      nameSpace: "flutter.mxlogger",
      storagePolicy: MXStoragePolicyType.yyyy_MM_dd,
      fileHeader: jsonEncode(header),
      consoleEnable: true,
      cryptKey: _cryptKey,
      iv: _iv,
    );

    logger.setMaxDiskAge(60 * 60 * 24 * 7);
    logger.setMaxDiskSize(1024 * 1024 * 10);
    logger.setLevel(0);

    debugPrint("diskcachePath:${logger.diskcachePath}");
    debugPrint("loggerKey:${logger.loggerKey}");

    if (!mounted) return;
    setState(() {
      _mxLogger = logger;
      _status = logger.diskcachePath;
    });
  }

  /// 写入覆盖 DEBUG–FATAL 全等级的样例日志（含 JSON 正文、多 tag、堆栈文本）
  void _writeLog() {
    final MXLogger? logger = _mxLogger;
    if (logger == null) return;

    logger.debug("这是条debug状态下的调试信息", name: "login", tag: "login,service");
    logger.debug("这是条debug状态下的调试信息", name: "register", tag: "register");

    final Map<String, dynamic> success = <String, dynamic>{
      "uri": "https://192.168.1.1/test",
      "method": "POST",
      "responseType": "ResponseType.json",
      "followRedirects": "true",
      "connectTimeout": "0",
      "receiveTimeout": "0",
      "extra": <String, dynamic>{"name": "张三"},
      "Request headers":
          "{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data": "{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode": 200,
      "Response Text": "{\"code\":0,\"msg\":\"操作成功\"}",
    };
    logger.info(jsonEncode(success), name: "network", tag: "network,POST,200");

    final Map<String, dynamic> notFound = <String, dynamic>{
      "uri": "https://192.168.1.1/test",
      "method": "GET",
      "responseType": "ResponseType.json",
      "followRedirects": "true",
      "connectTimeout": "0",
      "receiveTimeout": "0",
      "extra": <String, dynamic>{},
      "Request headers":
          "{\"content-type\":\"application/json; charset=utf-8\",\"accept-language\":\"zh\",\"service-name\":\"app\",\"token\":\"eyJhbGciOnIiwiYXVkIjoiY2xpmNvZGUiOiI3MTM0OTIxNCIsImV4cCI6MTY2NTYzMjc0MCwiaWF0IjoxNjYzNzMxOTQwfQ.xLzCwqvmMbePZgryLvlJ-AqAMcAZ32_JzucfKTLncFqA\",\"version\":\"2.2.0\",\"content-length\":\"97\"}",
      "Request data": "{mobile: 6666666666, logUrl: https://xxxx.txt}",
      "statusCode": 404,
      "Response Text": "{\"code\":404,\"msg\":\"not found\"}",
    };
    logger.warn(jsonEncode(notFound), name: "network", tag: "network,GET,404");

    const String flutterError = """
The following _TypeError was thrown building LogPage(dirty, state: _LogPageState#0b85e):
type 'Null' is not a subtype of type 'String'

The relevant error-causing widget was:
  LogPage LogPage:file:///xxxxxx/main2.dart:64:21
When the exception was thrown, this was the stack:
#0      _LogPageState.build (package:example/log_page.dart:45:12)
#1      StatefulElement.build (package:flutter/src/widgets/framework.dart:4919:27)
#2      ComponentElement.performRebuild (package:flutter/src/widgets/framework.dart:4806:15)
#3      StatefulElement.performRebuild (package:flutter/src/widgets/framework.dart:4977:11)
#4      Element.rebuild (package:flutter/src/widgets/framework.dart:4529:5)
#5      ComponentElement._firstBuild (package:flutter/src/widgets/framework.dart:4787:5)
#6      StatefulElement._firstBuild (package:flutter/src/widgets/framework.dart:4968:11)
#7      ComponentElement.mount (package:flutter/src/widgets/framework.dart:4781:5)
...     Normal element mounting (275 frames)
#282    Element.inflateWidget (package:flutter/src/widgets/framework.dart:3817:16)
#283    MultiChildRenderObjectElement.inflateWidget (package:flutter/src/widgets/framework.dart:6350:36)
#284    Element.updateChild (package:flutter/src/widgets/framework.dart:3551:18)
""";
    logger.error(flutterError, name: "flutter", tag: "flutter,crash");
    logger.fatal("数据库连接丢失，业务不可用", name: "database", tag: "db,fatal");

    _toast("已写入 6 条日志（${logger.logSize} byte）");
  }

  /// 批量写入，用于验证分页加载与等级分布条
  void _writeBatchLog() {
    final MXLogger? logger = _mxLogger;
    if (logger == null) return;
    for (int i = 0; i < 200; i++) {
      logger.log(i % 5, "批量日志 #$i", name: "batch", tag: "batch,level${i % 5}");
    }
    _toast("已写入 200 条日志（${logger.logSize} byte）");
  }

  Future<void> _showAnalyzer() async {
    final MXLogger? logger = _mxLogger;
    if (logger == null) return;
    // 悬浮球：拖动移位，单击打开分析器弹窗，双击关闭。
    // 分析器内核不依赖分享插件：主 app 自己接 share_plus 后经 share 注入，
    // 不注入则分析器里的「分享」降级为复制到剪贴板
    await MXAnalyzer.showDebug(
      _navigatorStateKey.currentState!.overlay!,
      diskcachePath: logger.diskcachePath,
      // 解密参数由主 app 全量传入（未加密传空数组）；多组时按顺序依次尝试
      cryptPairs: [
        MxCryptPair(key: logger.cryptKey ?? "", iv: logger.iv ?? ""),
        // MxCryptPair(key: "abchjilokiuihjng", iv: "abchjilokiuihqqq"),
      ],
      onShare: _shareWithSharePlus,
    );
  }

  void _toast(String message) {
    final NavigatorState? navigator = _navigatorStateKey.currentState;
    if (navigator == null) return;
    ScaffoldMessenger.of(navigator.context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorStateKey,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("MXAnalyzer 嵌入调试")),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(_status, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _mxLogger == null ? null : _writeLog,
                  child: const Text("写入日志（各等级样例）"),
                ),
                ElevatedButton(
                  onPressed: _mxLogger == null ? null : _writeBatchLog,
                  child: const Text("批量写入 200 条"),
                ),
                ElevatedButton(
                  onPressed: _mxLogger == null ? null : _showAnalyzer,
                  child: const Text("显示调试器（悬浮球）"),
                ),
                ElevatedButton(
                  onPressed: MXAnalyzer.dismiss,
                  child: const Text("隐藏调试器"),
                ),
                ElevatedButton(
                  onPressed: _mxLogger == null
                      ? null
                      : () {
                          _mxLogger!.removeAll();
                          _toast("已删除本机所有日志文件");
                        },
                  child: const Text("删除所有日志文件"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _navigatorStateKey.currentState?.push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const SecondPage(),
                      ),
                    );
                  },
                  child: const Text("进入二级页面（悬浮球应常驻）"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 二级页面：验证悬浮球挂在 Overlay 上，路由切换后依旧可见可用
class SecondPage extends StatelessWidget {
  const SecondPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("second")),
      body: const Center(child: Text("这是 push 进来的页面")),
    );
  }
}
