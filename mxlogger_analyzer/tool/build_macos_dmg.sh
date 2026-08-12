#!/usr/bin/env bash
# 构建 macOS 安装包（DMG）
#
# 用法：
#   ./tool/build_macos_dmg.sh            # 构建 release 并生成 DMG
#   ./tool/build_macos_dmg.sh --no-build # 跳过 flutter build，直接用已有产物打包
#
# 产物输出到 dist/ 目录，文件名带版本号，例如 dist/mxlogger_analyzer-1.0.0.dmg

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

# 从 pubspec.yaml 读取版本号（去掉 build number）
VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//' | cut -d+ -f1)"

SKIP_BUILD=false
[[ "${1:-}" == "--no-build" ]] && SKIP_BUILD=true

# 1. 构建 release 版 .app
if [[ "$SKIP_BUILD" == false ]]; then
  echo "==> flutter build macos --release"
  flutter build macos --release
fi

RELEASE_DIR="build/macos/Build/Products/Release"
APP_PATH="$(find "$RELEASE_DIR" -maxdepth 1 -name '*.app' | head -n1)"
if [[ -z "$APP_PATH" ]]; then
  echo "错误：未在 $RELEASE_DIR 找到 .app 产物，请先执行 flutter build macos --release" >&2
  exit 1
fi
APP_NAME="$(basename "$APP_PATH" .app)"
echo "==> 找到应用：$APP_PATH"

# 2. 准备 DMG 内容目录：.app + 指向 /Applications 的软链接（拖拽安装）
DIST_DIR="dist"
STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 3. 生成 DMG
mkdir -p "$DIST_DIR"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
rm -f "$DMG_PATH"

echo "==> 生成 $DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

echo ""
echo "✅ 完成：$DMG_PATH"
du -h "$DMG_PATH" | cut -f1 | xargs echo "   大小："
