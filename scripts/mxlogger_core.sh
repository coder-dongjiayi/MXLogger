#!/usr/bin/env bash
# 发布 MXLoggerCore.podspec 到 CocoaPods trunk。
#
# 用法：
#   scripts/mxlogger_core.sh
set -euo pipefail

# podspec 位于仓库根目录（本脚本的上一级）
cd "$(dirname "$0")/.."

pod trunk push --allow-warnings --verbose --skip-import-validation MXLoggerCore.podspec
