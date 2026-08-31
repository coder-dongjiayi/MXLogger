import 'dart:io';

/// 桌面端打包脚本：产出可直接分发的 macOS / Windows / Linux 可执行文件。
///
/// Flutter 桌面**不支持交叉编译**——每端产物只能在该系统上构建（macOS 的 .app 需要
/// Xcode 工具链，Windows 需要 MSVC，Linux 需要 GTK）。所以这个脚本设计成三端通用：
/// 在哪台机器上跑就出那一端的包，命令与产物命名完全一致；要三端齐全就在三台机器
/// （或 CI 的 macos / windows / ubuntu 三个 runner）上各跑一次同一条命令。
///
/// ```
/// dart run tool/build_desktop.dart                  # 构建当前平台 → dist/
/// dart run tool/build_desktop.dart --dmg            # macOS 额外产出 .dmg（拖拽安装）
/// dart run tool/build_desktop.dart --installer      # Windows 额外产出安装版 setup.exe（需 Inno Setup）
/// dart run tool/build_desktop.dart --no-build       # 复用已有构建产物，只重新打包
/// dart run tool/build_desktop.dart --clean          # 打包前先 flutter clean
/// dart run tool/build_desktop.dart --out=/tmp/pkg   # 换输出目录
/// dart run tool/build_desktop.dart --entry=lib/main_package.dart   # 换入口文件
/// ```
///
/// 产物命名：`<包名>-<版本>-<平台>-<架构>.<zip|tar.gz|dmg>`，
/// 例如 `mxlogger_analyzer-2.0.0-macos-arm64.zip`。
Future<void> main(List<String> args) async {
  final _Options options;
  try {
    options = _Options.parse(args);
  } on FormatException catch (error) {
    stderr.writeln("参数错误：${error.message}");
    stderr.writeln(_usage);
    exit(64);
  }

  // 脚本在 tool/ 下，一律切到工程根目录再干活（相对路径才稳）
  Directory.current = File(Platform.script.toFilePath()).parent.parent;

  final String pubspec = File("pubspec.yaml").readAsStringSync();
  final String appName = _field(pubspec, "name");
  // 版本号去掉 +build 号
  final String version = _field(pubspec, "version").split("+").first;

  if (!File(options.entry).existsSync()) {
    stderr.writeln("找不到入口文件 ${options.entry}（可用 --entry= 指定）");
    exit(66);
  }

  final _Platform target = _Platform.host();
  stdout.writeln("==> $appName $version → ${target.name}（${target.buildCommand} release）");

  if (options.clean) await _run("flutter", ["clean"]);

  if (options.build) {
    await _run("flutter", [
      "build",
      target.buildCommand,
      "--release",
      // 本工程没有 lib/main.dart，桌面壳入口是 main_desktop.dart，必须显式指定
      "-t",
      options.entry,
    ]);
  } else {
    stdout.writeln("==> 跳过构建（--no-build），直接打包已有产物");
  }

  final Directory outDir = Directory(options.out)..createSync(recursive: true);
  final List<File> artifacts = switch (target) {
    _Platform.macos => await _packageMacos(
        outDir: outDir, appName: appName, version: version, dmg: options.dmg),
    _Platform.windows => await _packageWindows(
        outDir: outDir,
        appName: appName,
        version: version,
        installer: options.installer),
    _Platform.linux =>
      await _packageLinux(outDir: outDir, appName: appName, version: version),
  };

  stdout.writeln("");
  stdout.writeln("✅ 完成，产物在 ${outDir.path}/");
  for (final File file in artifacts) {
    stdout.writeln("   ${file.path}  ${_size(file)}");
  }
  stdout.writeln("");
  stdout.writeln("其余两端在对应系统上执行同一条命令即可"
      "（Flutter 桌面不支持交叉编译）。");
}

const String _usage = """
用法：dart run tool/build_desktop.dart [选项]
  --no-build          复用已有构建产物，只重新打包
  --clean             打包前先 flutter clean
  --dmg               macOS 额外产出 .dmg（拖拽到 /Applications 安装）
  --installer         Windows 额外产出安装版 setup.exe（需要 Inno Setup / ISCC.exe）
  --out=<目录>        产物输出目录（默认 dist）
  --entry=<入口>      Dart 入口文件（默认 lib/main_desktop.dart）""";

/// 当前系统对应的打包目标：三端各自只能在本系统构建
enum _Platform {
  macos("macOS", "macos"),
  windows("Windows", "windows"),
  linux("Linux", "linux");

  const _Platform(this.name, this.buildCommand);

  final String name;

  /// `flutter build <buildCommand>`
  final String buildCommand;

  static _Platform host() {
    if (Platform.isMacOS) return _Platform.macos;
    if (Platform.isWindows) return _Platform.windows;
    if (Platform.isLinux) return _Platform.linux;
    stderr.writeln("不支持的系统：${Platform.operatingSystem}");
    exit(70);
  }
}

class _Options {
  _Options({
    required this.out,
    required this.entry,
    required this.build,
    required this.clean,
    required this.dmg,
    required this.installer,
  });

  factory _Options.parse(List<String> args) {
    final Map<String, String> map = {};
    for (final String arg in args) {
      if (!arg.startsWith("--")) throw FormatException("无法识别的参数 $arg");
      final int eq = arg.indexOf("=");
      if (eq < 0) {
        map[arg.substring(2)] = "true";
      } else {
        map[arg.substring(2, eq)] = arg.substring(eq + 1);
      }
    }
    if (map.containsKey("help")) {
      stdout.writeln(_usage);
      exit(0);
    }
    // 交叉编译在 Flutter 桌面上做不到，与其报「无法识别的参数」不如把话说清楚
    if (map.containsKey("target") || map.containsKey("platform")) {
      throw const FormatException(
          "不能指定目标平台：Flutter 桌面产物只能在对应系统上构建，请到那台机器上跑本脚本");
    }
    const Set<String> known = {
      "out", "entry", "no-build", "clean", "dmg", "installer", "help"
    };
    for (final String key in map.keys) {
      if (!known.contains(key)) throw FormatException("无法识别的参数 --$key");
    }
    final bool dmg = map["dmg"] == "true";
    if (dmg && !Platform.isMacOS) {
      throw const FormatException("--dmg 只在 macOS 上可用（hdiutil 是 macOS 自带工具）");
    }
    final bool installer = map["installer"] == "true";
    if (installer && !Platform.isWindows) {
      throw const FormatException("--installer 只在 Windows 上可用（依赖 Inno Setup）");
    }
    return _Options(
      out: map["out"] ?? "dist",
      entry: map["entry"] ?? "lib/main_desktop.dart",
      build: map["no-build"] != "true",
      clean: map["clean"] == "true",
      dmg: dmg,
      installer: installer,
    );
  }

  final String out;
  final String entry;
  final bool build;
  final bool clean;
  final bool dmg;
  final bool installer;
}

/// macOS：Release 目录下的 .app 打成 zip；`--dmg` 时再出一个可拖拽安装的 dmg。
Future<List<File>> _packageMacos({
  required Directory outDir,
  required String appName,
  required String version,
  required bool dmg,
}) async {
  const String releaseDir = "build/macos/Build/Products/Release";
  final Directory app = _find(
    Directory(releaseDir),
    (String path) => path.endsWith(".app"),
    hint: "未找到 .app：先执行不带 --no-build 的打包，或检查 $releaseDir",
  );
  final String base = "$appName-$version-macos-${_hostArch()}";
  final List<File> artifacts = [];

  // 用 ditto 而不是 zip：保留符号链接、资源分叉与权限位，否则解压出来的 .app 签名会坏
  final File zip = File("${outDir.path}/$base.zip");
  if (zip.existsSync()) zip.deleteSync();
  await _run("ditto", ["-c", "-k", "--keepParent", app.path, zip.path]);
  artifacts.add(zip);

  if (dmg) {
    final Directory staging = Directory.systemTemp.createTempSync("mx_dmg_");
    try {
      // dmg 里放 .app + 指向 /Applications 的软链接：打开后直接拖过去安装
      await _run("cp", ["-R", app.path, staging.path]);
      Link("${staging.path}/Applications").createSync("/Applications");
      final File file = File("${outDir.path}/$base.dmg");
      if (file.existsSync()) file.deleteSync();
      await _run("hdiutil", [
        "create",
        "-volname",
        _appLabel(app.path),
        "-srcfolder",
        staging.path,
        "-ov",
        "-format",
        "UDZO",
        file.path,
      ]);
      artifacts.add(file);
    } finally {
      staging.deleteSync(recursive: true);
    }
  }
  return artifacts;
}

/// Windows：Release 目录（exe + dll + data）整个打成 zip，压缩包内带一层同名目录；
/// `--installer` 时再用 Inno Setup 出一个安装版 setup.exe（安装向导 + 开始菜单/桌面快捷方式）。
Future<List<File>> _packageWindows({
  required Directory outDir,
  required String appName,
  required String version,
  required bool installer,
}) async {
  final ({Directory dir, String arch}) release = _archBundle(
    (String arch) => "build/windows/$arch/runner/Release",
    hint: "未找到 build/windows/<x64|arm64>/runner/Release",
  );
  final String base = "$appName-$version-windows-${release.arch}";
  final File zip = File("${outDir.path}/$base.zip");
  if (zip.existsSync()) zip.deleteSync();

  final Directory staging = Directory.systemTemp.createTempSync("mx_zip_");
  try {
    final String top = "${staging.path}\\$base";
    // Compress-Archive 只压目录本身，先把产物挪进一层同名目录，解压后不会散落一地
    await _run("powershell", [
      "-NoProfile",
      "-Command",
      "New-Item -ItemType Directory -Force -Path '$top' | Out-Null; "
          "Copy-Item -Path '${release.dir.path}\\*' -Destination '$top' -Recurse -Force; "
          "Compress-Archive -Path '$top' -DestinationPath '${zip.path}' -Force",
    ]);
  } finally {
    staging.deleteSync(recursive: true);
  }

  final List<File> artifacts = [zip];
  if (installer) {
    artifacts.add(await _buildWindowsInstaller(
      outDir: outDir,
      appName: appName,
      version: version,
      base: base,
      releaseDir: release.dir,
    ));
  }
  return artifacts;
}

/// 固定的 AppId：Inno Setup 用它识别「同一个应用」，覆盖安装/卸载都靠它，不能变。
const String _innoAppId = "{8C4A2F6E-1D3B-4E7A-9F05-B6C81D2A4E90}";

/// 用 Inno Setup（ISCC.exe）把 Release 目录编译成单文件安装包 `<base>-setup.exe`。
/// .iss 脚本按 pubspec 的版本号现场生成，不用手工维护一份配置文件。
Future<File> _buildWindowsInstaller({
  required Directory outDir,
  required String appName,
  required String version,
  required String base,
  required Directory releaseDir,
}) async {
  final String iscc = _findIscc();
  final File icon = File("windows/runner/resources/app_icon.ico");

  // Inno 的 {app}/{autopf} 等是它自己的占位符，这里全部来自字面拼接，不与 Dart 插值冲突
  final String iss = [
    "[Setup]",
    // AppId 里的 { 在 .iss 中要写成 {{ 转义
    "AppId={$_innoAppId",
    "AppName=$appName",
    "AppVersion=$version",
    "DefaultDirName={autopf}\\$appName",
    "DefaultGroupName=$appName",
    "UninstallDisplayIcon={app}\\$appName.exe",
    "OutputDir=${outDir.absolute.path}",
    "OutputBaseFilename=$base-setup",
    "Compression=lzma2",
    "SolidCompression=yes",
    "ArchitecturesInstallIn64BitMode=x64",
    "WizardStyle=modern",
    // 未签名的应用装到用户目录即可，不弹 UAC；想装到 Program Files 的用户可在向导里改
    "PrivilegesRequired=lowest",
    "PrivilegesRequiredOverridesAllowed=dialog",
    if (icon.existsSync()) "SetupIconFile=${icon.absolute.path}",
    "",
    "[Tasks]",
    'Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; '
        'GroupDescription: "{cm:AdditionalIcons}"',
    "",
    "[Files]",
    'Source: "${releaseDir.absolute.path}\\*"; DestDir: "{app}"; '
        "Flags: recursesubdirs ignoreversion",
    "",
    "[Icons]",
    'Name: "{group}\\$appName"; Filename: "{app}\\$appName.exe"',
    'Name: "{autodesktop}\\$appName"; Filename: "{app}\\$appName.exe"; Tasks: desktopicon',
    "",
    "[Run]",
    'Filename: "{app}\\$appName.exe"; Description: "{cm:LaunchProgram,$appName}"; '
        "Flags: nowait postinstall skipifsilent",
  ].join("\r\n");

  final Directory staging = Directory.systemTemp.createTempSync("mx_iss_");
  try {
    final File script = File("${staging.path}\\installer.iss")
      ..writeAsStringSync(iss);
    // ISCC.exe 路径带空格（Program Files），不走 cmd 壳，避免二次引号解析
    await _run(iscc, [script.path], shell: false);
  } finally {
    staging.deleteSync(recursive: true);
  }

  final File setup = File("${outDir.path}/$base-setup.exe");
  if (!setup.existsSync()) {
    stderr.writeln("Inno Setup 执行完但没找到 ${setup.path}");
    exit(70);
  }
  return setup;
}

/// 找 ISCC.exe：先探常见安装路径，再问 PATH。GitHub Actions 的 windows runner 预装了 Inno Setup。
String _findIscc() {
  const List<String> candidates = [
    r"C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    r"C:\Program Files\Inno Setup 6\ISCC.exe",
  ];
  for (final String path in candidates) {
    if (File(path).existsSync()) return path;
  }
  final ProcessResult which = Process.runSync("where", ["iscc"], runInShell: true);
  if (which.exitCode == 0) {
    final String path = (which.stdout as String).trim().split("\n").first.trim();
    if (path.isNotEmpty) return path;
  }
  stderr.writeln("未找到 Inno Setup（ISCC.exe）。--installer 需要先安装："
      "winget install JRSoftware.InnoSetup（GitHub Actions 的 windows runner 已预装）");
  exit(69);
}

/// Linux：bundle 目录（可执行文件 + lib + data）打成 tar.gz，保留可执行权限。
Future<List<File>> _packageLinux({
  required Directory outDir,
  required String appName,
  required String version,
}) async {
  final ({Directory dir, String arch}) bundle = _archBundle(
    (String arch) => "build/linux/$arch/release/bundle",
    hint: "未找到 build/linux/<x64|arm64>/release/bundle",
  );
  final String base = "$appName-$version-linux-${bundle.arch}";
  final File tar = File("${outDir.path}/$base.tar.gz");
  if (tar.existsSync()) tar.deleteSync();

  final Directory staging = Directory.systemTemp.createTempSync("mx_tar_");
  try {
    // 先复制成 <base>/ 再打包：解压出来是一个带版本号的目录，而不是散落的 bundle 内容
    await _run("cp", ["-R", bundle.dir.path, "${staging.path}/$base"]);
    await _run("tar", ["-czf", tar.absolute.path, "-C", staging.path, base]);
  } finally {
    staging.deleteSync(recursive: true);
  }
  return [tar];
}

/// Flutter 的桌面产物目录按架构分层（x64 / arm64），取存在的那一个
({Directory dir, String arch}) _archBundle(
  String Function(String arch) path, {
  required String hint,
}) {
  for (final String arch in ["x64", "arm64"]) {
    final Directory dir = Directory(path(arch));
    if (dir.existsSync()) return (dir: dir, arch: arch);
  }
  stderr.writeln(hint);
  exit(66);
}

Directory _find(Directory dir, bool Function(String path) test, {required String hint}) {
  if (dir.existsSync()) {
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is Directory && test(entity.path)) return entity;
    }
  }
  stderr.writeln(hint);
  exit(66);
}

/// dmg 卷名用 .app 的名字（含空格的应用名也照原样显示）
String _appLabel(String appPath) =>
    appPath.split(Platform.pathSeparator).last.replaceAll(".app", "");

/// macOS 的 .app 目录名里没有架构信息，用 uname -m 兜（x86_64 归一成 x64）
String _hostArch() {
  final ProcessResult result = Process.runSync("uname", ["-m"]);
  final String arch = (result.stdout as String).trim();
  return arch == "x86_64" ? "x64" : arch;
}

String _field(String pubspec, String key) {
  final RegExpMatch? match =
      RegExp("^$key:\\s*(.+)\$", multiLine: true).firstMatch(pubspec);
  if (match == null) {
    stderr.writeln("pubspec.yaml 里读不到 $key");
    exit(65);
  }
  return match.group(1)!.trim().replaceAll('"', "").replaceAll("'", "");
}

String _size(File file) {
  final double mb = file.lengthSync() / 1024 / 1024;
  return "${mb.toStringAsFixed(1)} MB";
}

/// 子进程直接继承标准输出：flutter build 的进度条原样透传，失败就带着退出码停下。
/// `shell: false` 用于直接执行带空格路径的 .exe（如 ISCC.exe），绕开 cmd 的引号解析。
Future<void> _run(String executable, List<String> arguments, {bool? shell}) async {
  stdout.writeln("\$ $executable ${arguments.join(" ")}");
  final Process process = await Process.start(
    executable,
    arguments,
    // Windows 上 flutter / powershell 是 .bat/.exe，走 shell 才能解析
    runInShell: shell ?? Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final int code = await process.exitCode;
  if (code != 0) {
    stderr.writeln("命令失败（退出码 $code）：$executable ${arguments.join(" ")}");
    exit(code);
  }
}
