#!/usr/bin/env bash
# 由发布脚本 source，参数为 podspec 路径。仅调整本机验证工程的编译目标，
# podspec 中对外声明的最低系统版本不变。临时配置在发布脚本退出时清理。

MXLOGGER_POD_VALIDATION_DIR=$(mktemp -d "${TMPDIR:-/tmp}/mxlogger-pod-validation.XXXXXX")
trap 'rm -rf "$MXLOGGER_POD_VALIDATION_DIR"' EXIT

python3 - "$MXLOGGER_POD_VALIDATION_DIR/validation.xcconfig" "$1" <<'PY'
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys


def version(value):
    return tuple(int(part) for part in value.split("."))


def sdk_minimum(platform):
    sdk = Path(subprocess.check_output(
        ["xcrun", "--sdk", platform, "--show-sdk-path"], text=True).strip())
    with (sdk / "SDKSettings.plist").open("rb") as source:
        return plistlib.load(source)["SupportedTargets"][platform]["MinimumDeploymentTarget"]


spec = json.loads(subprocess.check_output(["pod", "ipc", "spec", sys.argv[2]], text=True))
ios = max([spec["platforms"]["ios"], sdk_minimum("iphoneos"),
           sdk_minimum("iphonesimulator")], key=version)
macos = max([spec["platforms"]["osx"], sdk_minimum("macosx")], key=version)
lines = []
existing = os.environ.get("XCODE_XCCONFIG_FILE")
if existing:
    # Preserve other settings from an explicitly supplied validation config.
    lines.append("#include " + json.dumps(str(Path(existing).resolve()), ensure_ascii=False))
lines.extend([f"IPHONEOS_DEPLOYMENT_TARGET = {ios}",
              f"MACOSX_DEPLOYMENT_TARGET = {macos}"])
Path(sys.argv[1]).write_text("\n".join(lines) + "\n")
print(f"CocoaPods 本机编译验证目标：iOS {ios} / macOS {macos}（podspec 声明不变）")
PY

export XCODE_XCCONFIG_FILE="$MXLOGGER_POD_VALIDATION_DIR/validation.xcconfig"
