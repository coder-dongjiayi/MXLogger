#!/bin/bash
#
# 把 Core (C++) 与 platform/iOS/MXLogger (Objective-C) 组装成 SwiftPM 标准布局，
# 输出到镜像仓库 coder-dongjiayi/mxlogger-spm 的工作目录。
#
# 用法:
#   scripts/sync_spm_mirror.sh [输出目录]
#   输出目录省略时: 优先 ../mxlogger-spm (镜像仓库本地 clone)，不存在则 build/spm
#
# 保留输出目录的 .git、SwiftPM 缓存及本地 IDE 配置，分发源码以主仓库为准整体覆盖(含删除)。
# 之后在镜像目录里 commit / tag / push 即完成发版。
#
# Assemble Core (C++) and platform/iOS/MXLogger (Objective-C) into the standard SwiftPM layout and
# write it to the working tree of the mirror repository coder-dongjiayi/mxlogger-spm.
#
# Usage:
#   scripts/sync_spm_mirror.sh [output-dir]
#   Without an argument: ../mxlogger-spm (local clone of the mirror) if present, else build/spm
#
# Keep Git metadata, SwiftPM caches and local IDE settings. Replace generated distribution
# files (including deletions) to match the main repository.
#
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
if [ $# -ge 1 ]; then
    OUT=$1
elif [ -d "$ROOT/../mxlogger-spm" ]; then
    OUT=$ROOT/../mxlogger-spm
else
    OUT=$ROOT/build/spm
fi
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Sources/MXLoggerCore" "$STAGE/Sources/MXLogger"

# C++ 核心: 去掉测试、CMake、Xcode 工程等与 SwiftPM 无关的内容
# C++ core: drop tests, CMake and Xcode project files that SwiftPM does not use
rsync -a "$ROOT/Core/" "$STAGE/Sources/MXLoggerCore/" \
    --exclude tests \
    --exclude ffi \
    --exclude CMakeLists.txt \
    --exclude build.sh \
    --exclude MXLoggerCore.xcodeproj \
    --exclude .DS_Store

# Objective-C 层: 只要源码与公开头，Info.plist 属于 framework 工程
# Objective-C layer: sources and public header only; Info.plist belongs to the framework project
rsync -a "$ROOT/platform/iOS/MXLogger/MXLogger/" "$STAGE/Sources/MXLogger/" \
    --exclude Info.plist \
    --exclude .DS_Store

cp "$ROOT/spm/Package.swift" "$STAGE/Package.swift"
cp "$ROOT/spm/README.md"     "$STAGE/README.md"
cp "$ROOT/LICENSE.TXT"       "$STAGE/LICENSE"
printf '.build/\n.swiftpm/\n.DS_Store\nxcuserdata/\n' > "$STAGE/.gitignore"

# 保留 Git、SwiftPM 构建状态及本地 IDE 配置。
# Preserve Git metadata, SwiftPM build state and local IDE settings.
rsync -a --delete --exclude .git --exclude .build --exclude .swiftpm \
    --exclude .idea --exclude .vscode "$STAGE/" "$OUT/"

echo "SwiftPM mirror assembled at: $OUT"
