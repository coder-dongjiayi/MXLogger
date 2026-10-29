#!/usr/bin/env python3
"""Run macOS regression checks against local sources, including unpublished releases."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent


def version(value):
    return tuple(int(part) for part in value.split("."))


def sdk_info(platform):
    path = Path(subprocess.check_output(
        ["xcrun", "--sdk", platform, "--show-sdk-path"], text=True).strip())
    with (path / "SDKSettings.plist").open("rb") as file:
        settings = plistlib.load(file)
    return path, settings["SupportedTargets"][platform]["MinimumDeploymentTarget"]


def replace_once(path, before, after):
    text = path.read_text()
    if text.count(before) != 1:
        raise RuntimeError(f"Expected one occurrence of {before!r} in {path}")
    path.write_text(text.replace(before, after, 1))


def ruby_string(value):
    return "'" + str(value).replace("\\", "\\\\").replace("'", "\\'") + "'"


class Verification:
    def __init__(self, flutter, offline):
        output = ROOT / "build/macos-validation"
        output.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix="run-", dir=output))
        self.logs = self.directory / "logs"
        self.logs.mkdir()
        self.flutter = flutter
        self.offline = offline
        self.env = os.environ.copy()
        self.env["COCOAPODS_DISABLE_STATS"] = "true"
        self.env["MXLOGGER_LOCAL_NATIVE"] = "1"
        self.steps = []
        self.macos_sdk, macos_min = sdk_info("macosx")
        self.ios_sdk, ios_min = sdk_info("iphoneos")
        # Only verification fixtures follow the installed SDK's supported floor.
        self.macos_target = max(["10.15", macos_min], key=version)
        self.ios_target = max(["13.0", ios_min], key=version)
        config = self.directory / "validation.xcconfig"
        config.write_text(f"MACOSX_DEPLOYMENT_TARGET = {self.macos_target}\n"
                          f"IPHONEOS_DEPLOYMENT_TARGET = {self.ios_target}\n")
        self.env["XCODE_XCCONFIG_FILE"] = str(config)

    def run(self, name, command, cwd=ROOT, timeout=None):
        print(f">> {name}", flush=True)
        log = self.logs / f"{name}.log"
        try:
            with log.open("w") as file:
                subprocess.run([str(arg) for arg in command], cwd=cwd, env=self.env,
                               stdout=file, stderr=subprocess.STDOUT,
                               check=True, timeout=timeout)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            print("\n".join(log.read_text(errors="replace").splitlines()[-60:]),
                  file=sys.stderr)
            raise
        self.steps.append(name)
        return log.read_text(errors="replace")

    def ios_demo(self):
        # Build the checked-in Xcode project just as an iPhone Run would. The
        # validation override used for published pods must not hide stale
        # deployment targets in the Demo, framework or Core subprojects.
        for configuration in ["Debug", "Release"]:
            self.run(f"ios-native-demo-{configuration.lower()}",
                     ["env", "-u", "XCODE_XCCONFIG_FILE", "-u", "IPHONEOS_DEPLOYMENT_TARGET",
                      "xcodebuild", "-project", ROOT / "platform/iOS/MXLoggerDemo/MXLoggerDemo.xcodeproj",
                      "-scheme", "MXLoggerDemo", "-configuration", configuration,
                      "-destination", "generic/platform=iOS",
                      "-derivedDataPath", self.directory / "ios-native-demo" / configuration,
                      "CODE_SIGNING_ALLOWED=NO", "build"], timeout=600)

    def prepare(self, manager):
        stage = self.directory / manager
        plugin = stage / "platform/flutter_mxlogger"
        plugin.mkdir(parents=True)
        # The unit-test library builder resolves these relative to the plugin.
        for name in ["Core", "platform/Android"]:
            (stage / name).symlink_to(ROOT / name, target_is_directory=True)
        excludes = [".git", ".idea", ".dart_tool", "build", "Pods", "ephemeral",
                    ".symlinks", ".build", ".swiftpm", "FlutterFramework", "*.dylib",
                    "SDK.xcconfig", "Podfile.lock"]
        self.run(f"{manager}-copy", ["rsync", "-a"] +
                 [f"--exclude={item}" for item in excludes] +
                 [str(ROOT / "platform/flutter_mxlogger") + "/", str(plugin) + "/"])
        example = plugin / "example"
        (example / "macos/Runner/Configs/SDK.xcconfig").write_text(
            f"MXLOGGER_DEMO_DEPLOYMENT_TARGET = {self.macos_target}\n")
        replace_once(example / "pubspec.yaml", "\nflutter:\n",
                     "\nflutter:\n  config:\n    enable-swift-package-manager: " +
                     str(manager == "spm").lower() + "\n")
        project = example / "macos/Runner.xcodeproj/project.pbxproj"
        project.write_text(re.sub(r"MACOSX_DEPLOYMENT_TARGET = [0-9.]+;",
                                 f"MACOSX_DEPLOYMENT_TARGET = {self.macos_target};",
                                 project.read_text()))
        if manager == "spm":
            # Exercise SwiftPM alone, without falling back to CocoaPods.
            self.run("spm-deintegrate", ["pod", "deintegrate",
                                         example / "macos/Runner.xcodeproj"])
            (example / "macos/Podfile").unlink()
            workspace = example / "macos/Runner.xcworkspace/contents.xcworkspacedata"
            workspace.write_text(re.sub(
                r'\s*<FileRef\s+location\s*=\s*"group:Pods/Pods.xcodeproj">\s*</FileRef>',
                '', workspace.read_text()))
            for name in ["Flutter-Debug.xcconfig", "Flutter-Release.xcconfig"]:
                config = example / "macos/Flutter" / name
                config.write_text("\n".join(
                    line for line in config.read_text().splitlines()
                    if "Pods/Target Support Files" not in line) + "\n")
            self.run("spm-local-native", ["bash", ROOT / "scripts/sync_spm_mirror.sh",
                                         stage / "mxlogger-spm"])
            manifest = plugin / "darwin/flutter_mxlogger/Package.swift"
            text, count = re.subn(
                r'\.package\(url: "https://github\.com/coder-dongjiayi/mxlogger-spm\.git", exact: "[^"]+"\)',
                '.package(path: "../../../../mxlogger-spm")', manifest.read_text())
            if count != 1:
                raise RuntimeError("Could not locate the native SwiftPM dependency")
            manifest.write_text(text)
        else:
            podfile = example / "macos/Podfile"
            replace_once(podfile, "File.expand_path('../../../..', __dir__)",
                         ruby_string(ROOT))
            replace_once(podfile,
                         "demo_target = [Gem::Version.new('10.14'), Gem::Version.new(sdk_minimum)].max.to_s",
                         f"demo_target = '{self.macos_target}'")
        pub = [self.flutter, "pub", "get"] + (["--offline"] if self.offline else [])
        self.run(f"{manager}-pub", pub, cwd=plugin)
        return plugin

    def flutter_demo(self, manager, example):
        try:
            self.run(f"{manager}-demo", [self.flutter, "drive", "-d", "macos", "--no-pub",
                     "--driver=test_driver/integration_test.dart",
                     "--target=integration_test/macos_demo_test.dart"], cwd=example, timeout=600)
        finally:
            previews = self.logs / f"{manager}-demo-previews"
            previews.mkdir(exist_ok=True)
            for path in (example / "screenshots").glob("macos-*.png"):
                shutil.copy2(path, previews / path.name)

    def ios_bridge(self, plugin):
        source = plugin / "darwin/flutter_mxlogger/Sources/flutter_mxlogger"
        sdk_root = Path(self.flutter).resolve().parent.parent
        for platform, slice_name, suffix in [
            ("iphoneos", "ios-arm64", ""),
            ("iphonesimulator", "ios-arm64_x86_64-simulator", "-simulator"),
        ]:
            sdk = subprocess.check_output(
                ["xcrun", "--sdk", platform, "--show-sdk-path"], text=True).strip()
            framework = sdk_root / "bin/cache/artifacts/engine/ios/Flutter.xcframework" / slice_name
            for name in ["FlutterMxloggerPlugin.mm", "flutter-bridge.mm"]:
                self.run(f"{platform}-{name}", [
                    "xcrun", "clang++", "-std=c++17", "-fobjc-arc", "-fmodules",
                    f"-fmodules-cache-path={self.directory / 'modules'}",
                    "-target", f"arm64-apple-ios{self.ios_target}{suffix}",
                    "-isysroot", sdk, "-F", framework,
                    "-I", ROOT / "platform/iOS/MXLogger/MXLogger/include",
                    "-c", source / name, "-o", self.directory / f"{platform}-{name}.o",
                ])

    def flutter_checks(self, manager, unit_tests):
        plugin = self.prepare(manager)
        if unit_tests:
            self.run("flutter-analyze", [self.flutter, "analyze", "--no-pub"], cwd=plugin)
            self.run("flutter-unit-library", ["bash", "test/native/build_test_dylib.sh"], cwd=plugin)
            self.run("flutter-unit", [self.flutter, "test", "--no-pub", "--reporter", "expanded"], cwd=plugin)
            self.ios_bridge(plugin)
        example = plugin / "example"
        self.run(f"{manager}-integration", [self.flutter, "test",
                 "integration_test/macos_logger_test.dart", "-d", "macos",
                 "--no-pub", "--reporter", "expanded"], cwd=example)
        self.flutter_demo(manager, example)
        self.run(f"{manager}-release-build", [self.flutter, "build", "macos",
                 "--release", "-t", "integration_test/macos_release_smoke.dart",
                 "--no-pub"], cwd=example)
        app = example / "build/macos/Build/Products/Release/example.app"
        binary = app / "Contents/MacOS/example"
        output = self.run(f"{manager}-release-run", [binary], timeout=60)
        if "MXLOGGER_MACOS_RELEASE_SMOKE_OK" not in output:
            raise RuntimeError(f"{manager}: missing Release smoke success marker")
        library = (binary if manager == "spm" else
                   app / "Contents/Frameworks/flutter_mxlogger.framework/flutter_mxlogger")
        symbols = self.run(f"{manager}-release-symbols", ["xcrun", "nm", "-gU", library])
        bridge = plugin / "darwin/flutter_mxlogger/Sources/flutter_mxlogger/flutter-bridge.mm"
        expected = set(re.findall(r"MXLOGGERR_FUNC\((\w+)\)", bridge.read_text())) - {"func"}
        exported = set(re.findall(r"_flutter_mxlogger_(\w+)\s*$", symbols, re.MULTILINE))
        if not expected or expected - exported:
            raise RuntimeError(f"{manager}: missing FFI exports: {sorted(expected - exported)}")

    def summary(self, status):
        (self.logs / "summary.json").write_text(json.dumps({
            "status": status, "macos_validation_target": self.macos_target,
            "ios_validation_target": self.ios_target, "passed_steps": self.steps,
        }, indent=2) + "\n")
        print(f">> {status}; logs: {self.logs}", flush=True)

    def cleanup_builds(self):
        # These directories belong only to this unique verification run.
        for name in ["pods", "spm", "modules"]:
            path = self.directory / name
            if path.exists():
                shutil.rmtree(path)
        for path in self.directory.glob("*.o"):
            path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default=shutil.which("flutter"), help="Flutter executable (3.44+)")
    parser.add_argument("--package-manager", choices=["pods", "spm", "both"], default="both")
    parser.add_argument("--skip-native", action="store_true", help="Skip Core/Objective-C/Swift tests")
    parser.add_argument("--offline", action="store_true", help="Use cached Dart packages")
    parser.add_argument("--keep-builds", action="store_true", help="Keep successful Flutter fixtures (several GB)")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("Run this check on macOS with Xcode installed")
    flutter = shutil.which(args.flutter) if args.flutter else None
    if not flutter:
        parser.error("Flutter was not found; pass --flutter /path/to/flutter/bin/flutter")
    check = Verification(flutter, args.offline)
    print(f">> Validation workspace: {check.directory}", flush=True)
    try:
        info = json.loads(check.run("flutter-version", [flutter, "--version", "--machine"]))
        if version(info["frameworkVersion"].split("-")[0]) < (3, 44, 0):
            raise RuntimeError("This verification script requires Flutter 3.44+; the plugin still supports 3.7+")
        if not args.skip_native:
            check.run("core", ["bash", ROOT / "Core/tests/run_tests.sh"])
            check.run("core-installed-sdk", ["bash", ROOT / "scripts/verify_core_package.sh"])
            check.run("apple-native", ["bash", ROOT / "platform/iOS/MXLogger/tests/run_tests.sh"])
            check.ios_demo()
            check.run("native-demo", ["bash", ROOT / "scripts/verify_macos_demo.sh"])
        check.run("flutter-precache", [flutter, "precache", "--ios", "--macos"])
        managers = ["pods", "spm"] if args.package_manager == "both" else [args.package_manager]
        for index, manager in enumerate(managers):
            check.flutter_checks(manager, unit_tests=index == 0)
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        check.summary("FAILED")
        print(str(error), file=sys.stderr)
        return 1
    if not args.keep_builds:
        check.cleanup_builds()
    check.summary("PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
